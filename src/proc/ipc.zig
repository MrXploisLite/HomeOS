// Home OS - Inter-Process Communication (IPC)
// Copyright © 2025 Romy Rianata - Home OS

const serial = @import("../drivers/serial.zig");
const heap = @import("../mm/heap.zig");
const task = @import("task.zig");

pub const PIPE_BUFFER_SIZE: usize = 4096;
pub const MAX_PIPES: usize = 32;

pub const Pipe = struct {
    buffer: [PIPE_BUFFER_SIZE]u8,
    read_pos: usize,
    write_pos: usize,
    count: usize,
    read_open: bool,
    write_open: bool,
    reader_task: ?u32,
    writer_task: ?u32,

    pub fn init() Pipe {
        return Pipe{ .buffer = undefined, .read_pos = 0, .write_pos = 0, .count = 0, .read_open = true, .write_open = true, .reader_task = null, .writer_task = null };
    }

    pub fn write(self: *Pipe, data: []const u8) usize {
        if (!self.write_open) return 0;
        var written: usize = 0;
        for (data) |byte| {
            if (self.count >= PIPE_BUFFER_SIZE) break;
            self.buffer[self.write_pos] = byte;
            self.write_pos = (self.write_pos + 1) % PIPE_BUFFER_SIZE;
            self.count += 1;
            written += 1;
        }
        return written;
    }

    pub fn read(self: *Pipe, buffer: []u8) usize {
        if (!self.read_open and self.count == 0) return 0;
        var bytes_read: usize = 0;
        while (bytes_read < buffer.len and self.count > 0) {
            buffer[bytes_read] = self.buffer[self.read_pos];
            self.read_pos = (self.read_pos + 1) % PIPE_BUFFER_SIZE;
            self.count -= 1;
            bytes_read += 1;
        }
        return bytes_read;
    }

    pub fn available(self: *const Pipe) usize {
        return self.count;
    }
    pub fn space(self: *const Pipe) usize {
        return PIPE_BUFFER_SIZE - self.count;
    }
    pub fn closeRead(self: *Pipe) void {
        self.read_open = false;
    }
    pub fn closeWrite(self: *Pipe) void {
        self.write_open = false;
    }
    pub fn isClosed(self: *const Pipe) bool {
        return !self.read_open and !self.write_open;
    }
};

var pipes: [MAX_PIPES]Pipe = undefined;
var pipe_used: [MAX_PIPES]bool = [_]bool{false} ** MAX_PIPES;

pub fn createPipe() ?u32 {
    for (&pipe_used, 0..) |*used, i| {
        if (!used.*) {
            used.* = true;
            pipes[i] = Pipe.init();
            serial.write("IPC: Created pipe ");
            serial.writeInt(@truncate(i));
            serial.write("\n");
            return @truncate(i);
        }
    }
    return null;
}

pub fn getPipe(id: u32) ?*Pipe {
    if (id >= MAX_PIPES) return null;
    if (!pipe_used[id]) return null;
    return &pipes[id];
}

pub fn destroyPipe(id: u32) void {
    if (id >= MAX_PIPES) return;
    pipe_used[id] = false;
}

pub const MAX_MSG_SIZE: usize = 256;
pub const MAX_MESSAGES: usize = 16;
pub const MAX_QUEUES: usize = 16;
pub const MAX_SHM_REGIONS: usize = 16;
pub const MAX_SHM_SIZE: usize = 65536; // 64KB max
pub const MAX_SEMAPHORES: usize = 32;
pub const MAX_MUTEXES: usize = 32;

// ============================================================================
// MESSAGE QUEUES
// ============================================================================

pub const Message = struct {
    data: [MAX_MSG_SIZE]u8,
    len: usize,
    sender: u32,
    msg_type: u32,
};

pub const MessageQueue = struct {
    messages: [MAX_MESSAGES]Message,
    head: usize,
    tail: usize,
    count: usize,
    owner: u32,

    pub fn init(owner_id: u32) MessageQueue {
        return MessageQueue{
            .messages = undefined,
            .head = 0,
            .tail = 0,
            .count = 0,
            .owner = owner_id,
        };
    }

    pub fn send(self: *MessageQueue, data: []const u8, sender: u32, msg_type: u32) bool {
        if (self.count >= MAX_MESSAGES) return false;
        if (data.len > MAX_MSG_SIZE) return false;

        var msg = &self.messages[self.tail];
        for (data, 0..) |byte, i| {
            msg.data[i] = byte;
        }
        msg.len = data.len;
        msg.sender = sender;
        msg.msg_type = msg_type;

        self.tail = (self.tail + 1) % MAX_MESSAGES;
        self.count += 1;
        return true;
    }

    pub fn receive(self: *MessageQueue, buffer: []u8) ?Message {
        if (self.count == 0) return null;

        const msg = self.messages[self.head];
        self.head = (self.head + 1) % MAX_MESSAGES;
        self.count -= 1;

        // Copy to buffer
        const copy_len = @min(msg.len, buffer.len);
        for (0..copy_len) |i| {
            buffer[i] = msg.data[i];
        }

        return msg;
    }

    pub fn pending(self: *const MessageQueue) usize {
        return self.count;
    }
};

var msg_queues: [MAX_QUEUES]MessageQueue = undefined;
var queue_used: [MAX_QUEUES]bool = [_]bool{false} ** MAX_QUEUES;

pub fn createQueue(owner: u32) ?u32 {
    for (&queue_used, 0..) |*used, i| {
        if (!used.*) {
            used.* = true;
            msg_queues[i] = MessageQueue.init(owner);
            serial.write("IPC: Created message queue ");
            serial.writeInt(@truncate(i));
            serial.write("\n");
            return @truncate(i);
        }
    }
    return null;
}

pub fn getQueue(id: u32) ?*MessageQueue {
    if (id >= MAX_QUEUES) return null;
    if (!queue_used[id]) return null;
    return &msg_queues[id];
}

pub fn destroyQueue(id: u32) void {
    if (id >= MAX_QUEUES) return;
    queue_used[id] = false;
}

// ============================================================================
// SHARED MEMORY
// ============================================================================

pub const SharedMemory = struct {
    buffer: [MAX_SHM_SIZE]u8,
    size: usize,
    owner: u32,
    ref_count: u32,

    pub fn init(owner_id: u32, sz: usize) SharedMemory {
        return SharedMemory{
            .buffer = undefined,
            .size = @min(sz, MAX_SHM_SIZE),
            .owner = owner_id,
            .ref_count = 1,
        };
    }

    pub fn read(self: *const SharedMemory, offset: usize, dest: []u8) usize {
        if (offset >= self.size) return 0;
        const available = self.size - offset;
        const copy_len = @min(available, dest.len);
        for (0..copy_len) |i| {
            dest[i] = self.buffer[offset + i];
        }
        return copy_len;
    }

    pub fn write(self: *SharedMemory, offset: usize, data: []const u8) usize {
        if (offset >= self.size) return 0;
        const available = self.size - offset;
        const copy_len = @min(available, data.len);
        for (0..copy_len) |i| {
            self.buffer[offset + i] = data[i];
        }
        return copy_len;
    }

    pub fn attach(self: *SharedMemory) void {
        self.ref_count += 1;
    }

    pub fn detach(self: *SharedMemory) bool {
        if (self.ref_count > 0) self.ref_count -= 1;
        return self.ref_count == 0;
    }
};

var shm_regions: [MAX_SHM_REGIONS]SharedMemory = undefined;
var shm_used: [MAX_SHM_REGIONS]bool = [_]bool{false} ** MAX_SHM_REGIONS;

pub fn createShm(owner: u32, size: usize) ?u32 {
    for (&shm_used, 0..) |*used, i| {
        if (!used.*) {
            used.* = true;
            shm_regions[i] = SharedMemory.init(owner, size);
            serial.write("IPC: Created shared memory ");
            serial.writeInt(@truncate(i));
            serial.write(" (");
            serial.writeInt(@truncate(size));
            serial.write(" bytes)\n");
            return @truncate(i);
        }
    }
    return null;
}

pub fn getShm(id: u32) ?*SharedMemory {
    if (id >= MAX_SHM_REGIONS) return null;
    if (!shm_used[id]) return null;
    return &shm_regions[id];
}

pub fn destroyShm(id: u32) void {
    if (id >= MAX_SHM_REGIONS) return;
    shm_used[id] = false;
}

// ============================================================================
// SEMAPHORES
// ============================================================================

pub const Semaphore = struct {
    value: i32,
    max_value: i32,
    waiting: [task.MAX_TASKS]bool,
    waiting_count: u32,

    pub fn init(initial: i32, max: i32) Semaphore {
        return Semaphore{
            .value = initial,
            .max_value = max,
            .waiting = [_]bool{false} ** task.MAX_TASKS,
            .waiting_count = 0,
        };
    }

    pub fn wait(self: *Semaphore, task_id: u32) bool {
        if (self.value > 0) {
            self.value -= 1;
            return true;
        }
        // Would block - add to waiting list
        if (task_id < task.MAX_TASKS) {
            self.waiting[task_id] = true;
            self.waiting_count += 1;
        }
        return false;
    }

    pub fn tryWait(self: *Semaphore) bool {
        if (self.value > 0) {
            self.value -= 1;
            return true;
        }
        return false;
    }

    pub fn post(self: *Semaphore) bool {
        if (self.value >= self.max_value) return false;
        self.value += 1;
        // Wake one waiting task
        for (&self.waiting, 0..) |*w, i| {
            if (w.*) {
                w.* = false;
                self.waiting_count -= 1;
                serial.write("IPC: Semaphore woke task ");
                serial.writeInt(@truncate(i));
                serial.write("\n");
                break;
            }
        }
        return true;
    }

    pub fn getValue(self: *const Semaphore) i32 {
        return self.value;
    }
};

var semaphores: [MAX_SEMAPHORES]Semaphore = undefined;
var sem_used: [MAX_SEMAPHORES]bool = [_]bool{false} ** MAX_SEMAPHORES;

pub fn createSemaphore(initial: i32, max: i32) ?u32 {
    for (&sem_used, 0..) |*used, i| {
        if (!used.*) {
            used.* = true;
            semaphores[i] = Semaphore.init(initial, max);
            serial.write("IPC: Created semaphore ");
            serial.writeInt(@truncate(i));
            serial.write(" (value=");
            serial.writeInt(@as(u32, @intCast(initial)));
            serial.write(")\n");
            return @truncate(i);
        }
    }
    return null;
}

pub fn getSemaphore(id: u32) ?*Semaphore {
    if (id >= MAX_SEMAPHORES) return null;
    if (!sem_used[id]) return null;
    return &semaphores[id];
}

pub fn destroySemaphore(id: u32) void {
    if (id >= MAX_SEMAPHORES) return;
    sem_used[id] = false;
}

// ============================================================================
// MUTEXES
// ============================================================================

pub const Mutex = struct {
    locked: bool,
    owner: ?u32,
    waiting: [task.MAX_TASKS]bool,
    waiting_count: u32,

    pub fn init() Mutex {
        return Mutex{
            .locked = false,
            .owner = null,
            .waiting = [_]bool{false} ** task.MAX_TASKS,
            .waiting_count = 0,
        };
    }

    pub fn lock(self: *Mutex, task_id: u32) bool {
        if (!self.locked) {
            self.locked = true;
            self.owner = task_id;
            return true;
        }
        // Already locked - add to waiting
        if (task_id < task.MAX_TASKS) {
            self.waiting[task_id] = true;
            self.waiting_count += 1;
        }
        return false;
    }

    pub fn tryLock(self: *Mutex, task_id: u32) bool {
        if (!self.locked) {
            self.locked = true;
            self.owner = task_id;
            return true;
        }
        return false;
    }

    pub fn unlock(self: *Mutex, task_id: u32) bool {
        if (!self.locked) return false;
        if (self.owner != task_id) return false;

        // Wake one waiting task
        for (&self.waiting, 0..) |*w, i| {
            if (w.*) {
                w.* = false;
                self.waiting_count -= 1;
                self.owner = @truncate(i);
                serial.write("IPC: Mutex transferred to task ");
                serial.writeInt(@truncate(i));
                serial.write("\n");
                return true;
            }
        }

        self.locked = false;
        self.owner = null;
        return true;
    }

    pub fn isLocked(self: *const Mutex) bool {
        return self.locked;
    }

    pub fn getOwner(self: *const Mutex) ?u32 {
        return self.owner;
    }
};

var mutexes: [MAX_MUTEXES]Mutex = undefined;
var mutex_used: [MAX_MUTEXES]bool = [_]bool{false} ** MAX_MUTEXES;

pub fn createMutex() ?u32 {
    for (&mutex_used, 0..) |*used, i| {
        if (!used.*) {
            used.* = true;
            mutexes[i] = Mutex.init();
            serial.write("IPC: Created mutex ");
            serial.writeInt(@truncate(i));
            serial.write("\n");
            return @truncate(i);
        }
    }
    return null;
}

pub fn getMutex(id: u32) ?*Mutex {
    if (id >= MAX_MUTEXES) return null;
    if (!mutex_used[id]) return null;
    return &mutexes[id];
}

pub fn destroyMutex(id: u32) void {
    if (id >= MAX_MUTEXES) return;
    mutex_used[id] = false;
}

pub const Signal = enum(u8) {
    NONE = 0,
    SIGTERM = 1,
    SIGKILL = 2,
    SIGSTOP = 3,
    SIGCONT = 4,
    SIGUSR1 = 5,
    SIGUSR2 = 6,
    SIGCHLD = 7,
    SIGALRM = 8,
};

pub const MAX_PENDING_SIGNALS: usize = 8;
pub const SignalHandler = *const fn (Signal) void;

pub const SignalState = struct {
    pending: [MAX_PENDING_SIGNALS]Signal,
    pending_count: usize,
    handlers: [9]?SignalHandler,
    blocked: u16,

    pub fn init() SignalState {
        return SignalState{ .pending = [_]Signal{.NONE} ** MAX_PENDING_SIGNALS, .pending_count = 0, .handlers = [_]?SignalHandler{null} ** 9, .blocked = 0 };
    }

    pub fn send(self: *SignalState, sig: Signal) bool {
        if (self.pending_count >= MAX_PENDING_SIGNALS) return false;
        self.pending[self.pending_count] = sig;
        self.pending_count += 1;
        return true;
    }

    pub fn hasPending(self: *const SignalState) bool {
        return self.pending_count > 0;
    }

    pub fn getNext(self: *SignalState) ?Signal {
        if (self.pending_count == 0) return null;
        const sig = self.pending[0];
        var i: usize = 0;
        while (i < self.pending_count - 1) : (i += 1) {
            self.pending[i] = self.pending[i + 1];
        }
        self.pending_count -= 1;
        return sig;
    }
};

var task_signals: [task.MAX_TASKS]SignalState = undefined;
var signals_initialized: bool = false;

fn initSignals() void {
    if (signals_initialized) return;
    for (&task_signals) |*sig| {
        sig.* = SignalState.init();
    }
    signals_initialized = true;
}

pub fn sendSignal(task_id: u32, sig: Signal) bool {
    initSignals();
    if (task_id >= task.MAX_TASKS) return false;
    serial.write("IPC: Signal ");
    serial.writeInt(@intFromEnum(sig));
    serial.write(" -> task ");
    serial.writeInt(task_id);
    serial.write("\n");
    return task_signals[task_id].send(sig);
}

pub fn getSignalState(task_id: u32) ?*SignalState {
    initSignals();
    if (task_id >= task.MAX_TASKS) return null;
    return &task_signals[task_id];
}

pub fn init() void {
    serial.write("IPC: Initializing inter-process communication...\n");
    initSignals();
    serial.write("IPC: Ready\n");
}

pub fn getPipeCount() u32 {
    var count: u32 = 0;
    for (pipe_used) |used| {
        if (used) count += 1;
    }
    return count;
}

pub fn getQueueCount() u32 {
    var count: u32 = 0;
    for (queue_used) |used| {
        if (used) count += 1;
    }
    return count;
}

pub fn getShmCount() u32 {
    var count: u32 = 0;
    for (shm_used) |used| {
        if (used) count += 1;
    }
    return count;
}

pub fn getSemCount() u32 {
    var count: u32 = 0;
    for (sem_used) |used| {
        if (used) count += 1;
    }
    return count;
}

pub fn getMutexCount() u32 {
    var count: u32 = 0;
    for (mutex_used) |used| {
        if (used) count += 1;
    }
    return count;
}
