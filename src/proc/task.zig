// Home OS - Preemptive Multitasking
// Copyright © 2025 Romy Rianata - Home OS

const heap = @import("../mm/heap.zig");
const serial = @import("../drivers/serial.zig");
const tss = @import("../arch/tss.zig");
const vmm = @import("../mm/vmm.zig");
const pmm = @import("../mm/pmm.zig");

pub const TaskState = enum(u8) { ready = 0, running = 1, blocked = 2, terminated = 3 };

pub const Context = extern struct {
    edi: u32 = 0,
    esi: u32 = 0,
    ebp: u32 = 0,
    esp_dummy: u32 = 0,
    ebx: u32 = 0,
    edx: u32 = 0,
    ecx: u32 = 0,
    eax: u32 = 0,
    ds: u32 = 0x10,
    es: u32 = 0x10,
    fs: u32 = 0x10,
    gs: u32 = 0x10,
    eip: u32 = 0,
    cs: u32 = 0x08,
    eflags: u32 = 0x202,
    user_esp: u32 = 0,
    user_ss: u32 = 0,
};

pub const Task = struct {
    id: u32,
    name: [32]u8,
    state: TaskState,
    kernel_stack: u32,
    kernel_stack_base: u32,
    user_stack: u32,
    context_esp: u32,
    ring: u8,
    entry_point: u32,
    page_directory: u32,
    pages_allocated: u32,
    next: ?*Task,
    ticks: u32,
};

const KERNEL_STACK_SIZE: u32 = 4096;
const USER_STACK_SIZE: u32 = 4096;
pub const MAX_TASKS: u32 = 16;

var task_list: ?*Task = null;
var current_task: ?*Task = null;
var idle_task: ?*Task = null;
var next_task_id: u32 = 1;
var task_count: u32 = 0;
var scheduler_enabled: bool = false;
var scheduler_ticks: u32 = 0;
const TICKS_PER_SWITCH: u32 = 10;

pub fn init() void {
    serial.write("Task: Initializing preemptive multitasking...\n");
    task_list = null;
    current_task = null;
    idle_task = null;
    next_task_id = 1;
    task_count = 0;
    scheduler_enabled = false;
    scheduler_ticks = 0;
    serial.write("Task: Ready\n");
}

pub fn createKernelTask(name: []const u8, entry: *const fn () void) ?*Task {
    return createTaskInternal(name, @intFromPtr(entry), 0);
}

pub fn createUserTask(name: []const u8, entry: u32) ?*Task {
    return createTaskInternal(name, entry, 3);
}

fn createTaskInternal(name: []const u8, entry: u32, ring: u8) ?*Task {
    if (task_count >= MAX_TASKS) {
        serial.write("Task: Max tasks reached\n");
        return null;
    }
    const task_mem = heap.alloc(@sizeOf(Task));
    if (task_mem == null) {
        serial.write("Task: Failed to allocate PCB\n");
        return null;
    }
    const task: *Task = @ptrCast(@alignCast(task_mem));

    // Zero-initialize the entire Task struct to avoid garbage values
    const task_bytes: [*]u8 = @ptrCast(task);
    for (0..@sizeOf(Task)) |i| {
        task_bytes[i] = 0;
    }

    const kstack = heap.alloc(KERNEL_STACK_SIZE);
    if (kstack == null) {
        serial.write("Task: Failed to allocate kernel stack\n");
        return null;
    }

    task.id = next_task_id;
    next_task_id += 1;
    var i: usize = 0;
    while (i < name.len and i < 31) : (i += 1) {
        task.name[i] = name[i];
    }
    task.name[i] = 0;
    task.state = .ready;
    task.ring = ring;
    task.entry_point = entry;
    task.ticks = 0;
    task.next = null;
    task.pages_allocated = 0;
    task.kernel_stack_base = @intFromPtr(kstack);
    task.kernel_stack = task.kernel_stack_base + KERNEL_STACK_SIZE;

    if (ring == 3) {
        const addr_space = vmm.AddressSpace.create();
        if (addr_space) |as| {
            task.page_directory = as.page_directory;
        } else {
            task.page_directory = vmm.getCurrentPageDir();
        }
    } else {
        task.page_directory = vmm.getCurrentPageDir();
    }

    if (ring == 3) {
        const ustack = heap.alloc(USER_STACK_SIZE);
        if (ustack == null) {
            serial.write("Task: Failed to allocate user stack\n");
            return null;
        }
        task.user_stack = @intFromPtr(ustack) + USER_STACK_SIZE;
    } else {
        task.user_stack = 0;
    }

    setupInitialContext(task);
    addToTaskList(task);
    task_count += 1;
    serial.write("Task: Created '");
    serial.write(name);
    serial.write("' (ID=");
    serial.writeInt(task.id);
    serial.write(", Ring=");
    serial.writeInt(@as(u32, ring));
    serial.write(")\n");
    return task;
}

fn setupInitialContext(task: *Task) void {
    var esp = task.kernel_stack;
    if (task.ring == 3) {
        esp -= 4;
        writeStack(esp, 0x23);
        esp -= 4;
        writeStack(esp, task.user_stack);
    }
    esp -= 4;
    writeStack(esp, 0x202);
    if (task.ring == 3) {
        esp -= 4;
        writeStack(esp, 0x1B);
    } else {
        esp -= 4;
        writeStack(esp, 0x08);
    }
    esp -= 4;
    writeStack(esp, task.entry_point);
    const ds: u32 = if (task.ring == 3) 0x23 else 0x10;
    esp -= 4;
    writeStack(esp, ds);
    esp -= 4;
    writeStack(esp, ds);
    esp -= 4;
    writeStack(esp, ds);
    esp -= 4;
    writeStack(esp, ds);
    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        esp -= 4;
        writeStack(esp, 0);
    }
    task.context_esp = esp;
}

fn writeStack(addr: u32, value: u32) void {
    const ptr: *volatile u32 = @ptrFromInt(addr);
    ptr.* = value;
}

fn addToTaskList(task: *Task) void {
    if (task_list == null) {
        task_list = task;
    } else {
        var last = task_list;
        while (last.?.next != null) {
            last = last.?.next;
        }
        last.?.next = task;
    }
}

pub fn enableScheduler() void {
    scheduler_enabled = true;
    serial.write("Task: Scheduler enabled\n");
}
pub fn disableScheduler() void {
    scheduler_enabled = false;
}

pub export fn timerTick(current_esp: u32) callconv(.c) u32 {
    scheduler_ticks += 1;
    if (!scheduler_enabled) return 0;
    if (current_task == null) return 0;
    current_task.?.ticks += 1;
    if (scheduler_ticks < TICKS_PER_SWITCH) return 0;
    scheduler_ticks = 0;
    const next = findNextTask();
    if (next == null or next == current_task) return 0;
    return switchContext(current_esp, next.?);
}

fn findNextTask() ?*Task {
    if (task_list == null) return null;
    var start: ?*Task = null;
    if (current_task != null) {
        start = current_task.?.next;
    }
    if (start == null) {
        start = task_list;
    }
    var task = start;
    var checked: u32 = 0;
    while (checked < task_count) : (checked += 1) {
        if (task) |t| {
            if (t.state == .ready and t != current_task) return t;
            task = t.next;
            if (task == null) task = task_list;
        } else break;
    }
    return null;
}

fn switchContext(old_esp: u32, new_task: *Task) u32 {
    if (current_task) |old| {
        old.context_esp = old_esp;
        if (old.state == .running) old.state = .ready;
    }
    current_task = new_task;
    new_task.state = .running;
    tss.setKernelStack(new_task.kernel_stack);
    const current_pd = vmm.getCurrentPageDir();
    if (new_task.page_directory != current_pd and new_task.page_directory != 0) {
        asm volatile ("mov %[pd], %%cr3"
            :
            : [pd] "r" (new_task.page_directory),
        );
    }
    return new_task.context_esp;
}

pub fn yield() void {
    if (!scheduler_enabled) return;
    if (current_task == null) return;
    current_task.?.state = .ready;
}

pub fn exitTask(status: u32) void {
    _ = status;
    if (current_task) |t| {
        serial.write("Task: '");
        serial.write(getTaskName(t));
        serial.write("' terminated\n");
        t.state = .terminated;
        if (t.ring == 3 and t.page_directory != 0) {
            const kernel_pd = vmm.getCurrentPageDir();
            if (t.page_directory != kernel_pd) {
                var as = vmm.AddressSpace{ .page_directory = t.page_directory };
                as.destroy();
                t.page_directory = 0;
            }
        }
    }
}

pub fn getTaskMemory(t: *const Task) u32 {
    return t.pages_allocated;
}
pub fn getTaskPageDir(t: *const Task) u32 {
    return t.page_directory;
}
pub fn blockTask() void {
    if (current_task) |task| task.state = .blocked;
}
pub fn unblockTask(task: *Task) void {
    if (task.state == .blocked) task.state = .ready;
}
pub fn getCurrentTask() ?*Task {
    return current_task;
}
pub fn setCurrentTask(task: *Task) void {
    current_task = task;
    task.state = .running;
}
pub fn getTaskCount() u32 {
    return task_count;
}

/// Task info for GUI display - uses static buffer to avoid pointer issues
pub const TaskInfo = struct {
    id: u32,
    name: [32]u8,
    name_len: usize,
    state: u8,
    ring: u8,

    pub fn getName(self: *const TaskInfo) []const u8 {
        return self.name[0..self.name_len];
    }
};

// Static buffer for task info to avoid memory issues
var task_info_buffer: TaskInfo = undefined;

/// Get task info by index (for GUI task manager)
pub fn getTaskInfo(index: usize) ?*const TaskInfo {
    if (task_list == null) return null;

    var t = task_list;
    var i: usize = 0;
    while (t) |tsk| {
        if (i == index) {
            // Copy data to static buffer
            task_info_buffer.id = tsk.id;
            task_info_buffer.state = @intFromEnum(tsk.state);
            task_info_buffer.ring = tsk.ring;

            // Copy name
            var name_len: usize = 0;
            while (name_len < 32 and tsk.name[name_len] != 0) : (name_len += 1) {
                task_info_buffer.name[name_len] = tsk.name[name_len];
            }
            task_info_buffer.name_len = name_len;

            return &task_info_buffer;
        }
        i += 1;
        t = tsk.next;
    }
    return null;
}

pub fn getTaskName(task: *const Task) []const u8 {
    var len: usize = 0;
    while (len < 32 and task.name[len] != 0) : (len += 1) {}
    return task.name[0..len];
}

pub fn listTasks(callback: *const fn (*const Task) void) void {
    var t = task_list;
    while (t) |task| {
        callback(task);
        t = task.next;
    }
}

pub fn getTaskById(id: u32) ?*Task {
    var t = task_list;
    while (t) |task| {
        if (task.id == id) return task;
        t = task.next;
    }
    return null;
}

pub fn createIdleTask() void {
    idle_task = createKernelTask("idle", &idleLoop);
    if (idle_task) |task| setCurrentTask(task);
}

fn idleLoop() void {
    while (true) {
        asm volatile ("hlt");
    }
}
