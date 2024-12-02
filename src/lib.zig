const std = @import("std");
const c = @cImport({
    @cDefine("NAPI_VERSION", "8");
    @cDefine("NAPI_EXTERN", "__attribute__((weak))");
    @cDefine("NAPI_MODULE_EXPORT", "__attribute__((visibility(\"default\")))");
    @cInclude("node_api.h");
    // @cInclude("napi.h");
});
const Child = std.process.Child;
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const AtomicBool = std.atomic.Value(bool);

// Error set
const GenerateError = error{
    TimeoutError,
    ProcessError,
};

// Output format types
const OutputFormat = enum {
    PDF,
    Excel,
};

// Enhanced configuration
const Config = struct {
    pdf_engine_path: []const u8,
    excel_engine_path: []const u8,
    temp_dir: []const u8,
    buffer_size: usize,
    max_concurrent_jobs: usize,
    timeout_ms: i64,

    pub fn init() Config {
        return .{
            .pdf_engine_path = "wkhtmltopdf",
            .excel_engine_path = "node",
            .temp_dir = "/tmp",
            .buffer_size = 1024 * 1024 * 50,  // เพิ่มเป็น 50MB
            .max_concurrent_jobs = 4,
            .timeout_ms = 600000,  // เพิ่มเป็น 10 นาที
        };
    }

    pub fn validate(self: Config) !void {
        if (self.temp_dir.len == 0) return error.InvalidArgument;
        if (self.pdf_engine_path.len == 0) return error.InvalidArgument;
        if (self.excel_engine_path.len == 0) return error.InvalidArgument;
        if (self.timeout_ms == 0) return error.InvalidArgument;
    }
};

// เพิ่ม Memory Pool สำหรับจัดการ buffer
const MemoryPool = struct {
    const Block = struct {
        data: []u8,
        in_use: bool,
    };

    blocks: []Block,
    mutex: Mutex = .{},
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, block_size: usize, block_count: usize) !*MemoryPool {
        const self = try allocator.create(MemoryPool);
        self.* = .{
            .blocks = try allocator.alloc(Block, block_count),
            .allocator = allocator,
        };

        for (self.blocks) |*block| {
            block.* = .{
                .data = try allocator.alloc(u8, block_size),
                .in_use = false,
            };
        }
        return self;
    }

    pub fn acquire(self: *MemoryPool) ?[]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.blocks) |*block| {
            if (!block.in_use) {
                block.in_use = true;
                return block.data;
            }
        }
        return null;
    }

    pub fn release(self: *MemoryPool, buffer: []u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.blocks) |*block| {
            if (block.data.ptr == buffer.ptr) {
                block.in_use = false;
                return;
            }
        }
    }

    pub fn deinit(self: *MemoryPool) void {
        for (self.blocks) |block| {
            self.allocator.free(block.data);
        }
        self.allocator.free(self.blocks);
        self.allocator.destroy(self);
    }
};

// ปรับปรุง JobQueue ให้ใช้ Thread Pool
const JobQueue = struct {
    const Job = struct {
        format: OutputFormat,
        input: []const u8,
        callback: *const fn (ctx: *anyopaque, data: [*]const u8, len: usize) void,
        error_callback: *const fn (ctx: *anyopaque, msg: [*]const u8, len: usize) void,
        callback_ctx: *anyopaque,
        error_ctx: *anyopaque,
    };

    queue: std.ArrayList(Job),
    mutex: Mutex = .{},
    workers: []Thread,
    running: bool,
    semaphore: Thread.Semaphore,
    allocator: std.mem.Allocator,
    memory_pool: *MemoryPool,

    pub fn init(allocator: std.mem.Allocator, worker_count: usize, memory_pool: *MemoryPool) !*JobQueue {
        const self = try allocator.create(JobQueue);
        self.* = .{
            .queue = std.ArrayList(Job).init(allocator),
            .workers = try allocator.alloc(Thread, worker_count),
            .running = true,
            .semaphore = .{ .permits = 0 },
            .allocator = allocator,
            .memory_pool = memory_pool,
        };

        // Initialize worker threads
        for (self.workers, 0..) |*worker, i| {
            worker.* = try Thread.spawn(.{}, workerFunction, .{ self, i });
        }

        return self;
    }

    fn workerFunction(self: *JobQueue, worker_id: usize) void {
        while (self.running) {
            _ = self.semaphore.wait();
            
            const job = self.getNextJob() orelse continue;

            if (GeneratorStorage.get()) |gen| {
                gen.processJob(job) catch |err| {
                    const error_msg = std.fmt.allocPrint(
                        self.allocator,
                        "Worker {d} error: {s}",
                        .{ worker_id, @errorName(err) }
                    ) catch continue;
                    job.error_callback(job.error_ctx, error_msg.ptr, error_msg.len);
                };
            } else {
                const error_msg = std.fmt.allocPrint(
                    self.allocator,
                    "Worker {d} error: Generator not initialized",
                    .{worker_id}
                ) catch continue;
                job.error_callback(job.error_ctx, error_msg.ptr, error_msg.len);
            }
        }
    }

    fn getNextJob(self: *JobQueue) ?Job {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.queue.items.len == 0) return null;
        return self.queue.orderedRemove(0);
    }

    pub fn addJob(self: *JobQueue, job: Job) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.queue.append(job);
        self.semaphore.post();
    }

    pub fn deinit(self: *JobQueue) void {
        self.running = false;
        for (0..self.workers.len) |_| {
            self.semaphore.post();
        }
        for (self.workers) |worker| {
            worker.join();
        }
        self.allocator.free(self.workers);
        self.queue.deinit();
        self.allocator.destroy(self);
    }
};

// ปรับปรุง DocumentGenerator
const DocumentGenerator = struct {
    config: Config,
    job_queue: *JobQueue,
    memory_pool: *MemoryPool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: Config) !*DocumentGenerator {
        try config.validate();
        
        const memory_pool = try MemoryPool.init(
            allocator,
            config.buffer_size,
            config.max_concurrent_jobs * 2
        );
        
        const self = try allocator.create(DocumentGenerator);
        self.* = .{
            .config = config,
            .memory_pool = memory_pool,
            .job_queue = try JobQueue.init(allocator, config.max_concurrent_jobs, memory_pool),
            .allocator = allocator,
        };
        return self;
    }

    pub fn generateDocument(self: *DocumentGenerator, format: OutputFormat, input: []const u8) ![]const u8 {
        var result: ?[]const u8 = null;
        var error_message: ?[]const u8 = null;

        const OnSuccess = struct {
            result_ptr: *?[]const u8,
            
            fn callback(ctx: *anyopaque, data: [*]const u8, len: usize) void {
                const Self = @This();
                const this = @as(*Self, @alignCast(@ptrCast(ctx)));
                const slice = data[0..len];
                this.result_ptr.* = slice;
            }
        };

        const OnError = struct {
            error_ptr: *?[]const u8,
            
            fn callback(ctx: *anyopaque, msg: [*]const u8, len: usize) void {
                const Self = @This();
                const this = @as(*Self, @alignCast(@ptrCast(ctx)));
                const slice = msg[0..len];
                this.error_ptr.* = slice;
            }
        };

        var success_ctx = OnSuccess{ .result_ptr = &result };
        var error_ctx = OnError{ .error_ptr = &error_message };

        try self.job_queue.addJob(.{
            .format = format,
            .input = input,
            .callback = OnSuccess.callback,
            .error_callback = OnError.callback,
            .callback_ctx = &success_ctx,
            .error_ctx = &error_ctx,
        });

        // Wait for result with timeout
        const start_time = std.time.milliTimestamp();
        while (result == null and error_message == null) {
            if (std.time.milliTimestamp() - start_time > self.config.timeout_ms) {
                return error.TimeoutError;
            }
            std.time.sleep(10 * std.time.ns_per_ms);
        }

        if (error_message) |msg| {
            std.debug.print("Error: {s}\n", .{msg});
            self.allocator.free(msg);
            return error.ProcessError;
        }

        return result.?;
    }

    pub fn processJob(self: *DocumentGenerator, job: JobQueue.Job) !void {
        const result = switch (job.format) {
            .PDF => try self.processPDFJob(job.input),
            .Excel => try self.processExcelJob(job.input),
        };
        
        // Convert result to [*]const u8
        const ptr: [*]const u8 = @ptrCast(result.ptr);
        job.callback(job.callback_ctx, ptr, result.len);
    }

    fn processPDFJob(self: *DocumentGenerator, input: []const u8) ![]const u8 {
        // Debug: Print PDF engine path
        std.debug.print("PDF engine path: {s}\n", .{self.config.pdf_engine_path});

        // Create temporary file paths
        const timestamp = @as(i64, @intCast(std.time.timestamp()));
        const output_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/output_{d}.pdf",
            .{ self.config.temp_dir, timestamp }
        );
        defer self.allocator.free(output_path);

        var child = std.process.Child.init(
            &[_][]const u8{ 
                self.config.pdf_engine_path,
                "--quiet",
                "--encoding", "UTF-8",
                "--enable-local-file-access",
                "--disable-smart-shrinking",
                "--margin-top", "10mm",
                "--margin-right", "10mm",
                "--margin-bottom", "10mm",
                "--margin-left", "10mm",
                "-",              // Read from stdin
                output_path,      // Write to temp file
            },
            self.allocator
        );
        
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        
        try child.spawn();
        
        // Write input to stdin
        if (child.stdin) |stdin| {
            try stdin.writeAll(input);
            stdin.close();
            child.stdin = null;
        }

        // Read stderr for error messages
        var stderr_msg: []const u8 = "";
        if (child.stderr) |stderr| {
            stderr_msg = stderr.reader().readAllAlloc(self.allocator, self.config.buffer_size) catch "";
        }
        defer if (stderr_msg.len > 0) self.allocator.free(stderr_msg);

        // Wait for process to finish
        const result = try child.wait();
        
        // Check result and print debug info
        if (result != .Exited or result.Exited != 0) {
            std.debug.print("PDF generation failed. Exit code: {}\n", .{result});
            if (stderr_msg.len > 0) {
                std.debug.print("Error message: {s}\n", .{stderr_msg});
            }
            return error.ProcessError;
        }

        // Read the generated PDF file
        const output_file = try std.fs.cwd().openFile(output_path, .{});
        defer output_file.close();
        defer std.fs.cwd().deleteFile(output_path) catch {};

        return try output_file.reader().readAllAlloc(
            self.allocator,
            self.config.buffer_size
        );
    }

    fn processExcelJob(self: *DocumentGenerator, input: []const u8) ![]const u8 {
        const timestamp = @as(i64, @intCast(std.time.timestamp()));
        
        const temp_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/temp_{d}.html",
            .{ self.config.temp_dir, timestamp }
        );
        defer self.allocator.free(temp_path);

        const output_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/output_{d}.xlsx",
            .{ self.config.temp_dir, timestamp }
        );
        defer self.allocator.free(output_path);

        // เปลี่ยนชื่อตัวแปร file เป็น temp_file และ output_file
        const temp_file = try std.fs.cwd().createFile(temp_path, .{
            .read = true,
            .truncate = true,
        });
        defer temp_file.close();
        
        try temp_file.writeAll(input);

        // Convert to Excel
        var child_process = std.process.Child.init(
            &[_][]const u8{ 
                self.config.excel_engine_path, 
                temp_path, 
                output_path 
            },
            self.allocator
        );
        
        child_process.stdin_behavior = .Pipe;
        child_process.stdout_behavior = .Pipe;
        child_process.stderr_behavior = .Pipe;
        
        try child_process.spawn();
        
        const result = try child_process.wait();
        if (result != .Exited or result.Exited != 0) {
            return error.ProcessError;
        }

        // Read result
        const output_file = try std.fs.cwd().openFile(output_path, .{});
        defer output_file.close();
        defer std.fs.cwd().deleteFile(output_path) catch {};

        return try output_file.reader().readAllAlloc(
            self.allocator,
            self.config.buffer_size
        );
    }

    pub fn deinit(self: *DocumentGenerator) void {
        self.job_queue.deinit();
        self.allocator.destroy(self);
    }
};

// ใพิ่ม GeneratorStorage struct
const GeneratorStorage = struct {
    var instance: ?*DocumentGenerator = null;

    pub fn get() ?*DocumentGenerator {
        return instance;
    }

    pub fn set(gen: ?*DocumentGenerator) void {
        instance = gen;
    }
};

var is_initialized: AtomicBool = AtomicBool.init(false);
var generator_instance: ?*DocumentGenerator = null;

// Node.js module registration
export fn napi_register_module_v1(
    env: c.napi_env,
    exports: c.napi_value,
) c.napi_value {
    // Register the module functions
    var result: c.napi_status = undefined;
    
    // Register init
    var init_fn: c.napi_value = undefined;
    result = c.napi_create_function(env, "init", 4, init, null, &init_fn);
    if (result == c.napi_ok) {
        _ = c.napi_set_named_property(env, exports, "init", init_fn);
    }

    // Register generatePDF
    var pdf_fn: c.napi_value = undefined;
    result = c.napi_create_function(env, "generatePDF", 10, generatePDF, null, &pdf_fn);
    if (result == c.napi_ok) {
        _ = c.napi_set_named_property(env, exports, "generatePDF", pdf_fn);
    }

    // Register generateExcel
    var excel_fn: c.napi_value = undefined;
    result = c.napi_create_function(env, "generateExcel", 12, generateExcel, null, &excel_fn);
    if (result == c.napi_ok) {
        _ = c.napi_set_named_property(env, exports, "generateExcel", excel_fn);
    }

    // Register cleanup
    var cleanup_fn: c.napi_value = undefined;
    result = c.napi_create_function(env, "cleanup", 7, cleanup, null, &cleanup_fn);
    if (result == c.napi_ok) {
        _ = c.napi_set_named_property(env, exports, "cleanup", cleanup_fn);
    }

    return exports;
}

// Change the cleanup function signature to mark unused parameters
export fn cleanup(
    _: c.napi_env,
    _: c.napi_callback_info,
) c.napi_value {
    if (generator_instance) |gen| {
        gen.deinit();
        generator_instance = null;
        GeneratorStorage.set(null);
        is_initialized.store(false, .seq_cst);
    }
    return null;
}

// Async function handlers
fn generatePDFAsync(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    return generateDocumentAsync(env, info, .PDF);
}

fn generateExcelAsync(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    return generateDocumentAsync(env, info, .Excel);
}

fn generateDocumentAsync(env: c.napi_env, info: c.napi_callback_info, format: OutputFormat) c.napi_value {
    const gen = generator_instance orelse {
        var error_msg: c.napi_value = undefined;
        _ = c.napi_create_string_utf8(env, "Generator not initialized", 23, &error_msg);
        _ = c.napi_throw(env, error_msg);
        return null;
    };

    // Create promise
    var promise: c.napi_value = undefined;
    var deferred: c.napi_deferred = undefined;
    if (c.napi_create_promise(env, &deferred, &promise) != c.napi_ok) {
        return null;
    }

    // Get arguments
    var argc: usize = 1;
    var args: [1]c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &args, null, null) != c.napi_ok) {
        rejectPromise(env, deferred, "Failed to get arguments");
        return promise;
    }

    // Get input content length
    var input_len: usize = undefined;
    if (c.napi_get_value_string_utf8(env, args[0], null, 0, &input_len) != c.napi_ok) {
        rejectPromise(env, deferred, "Failed to get content length");
        return promise;
    }

    // Allocate buffer for input
    const input_buffer = gen.allocator.alloc(u8, input_len + 1) catch {
        rejectPromise(env, deferred, "Memory allocation failed");
        return promise;
    };
    defer gen.allocator.free(input_buffer);

    // Get input content
    if (c.napi_get_value_string_utf8(env, args[0], input_buffer.ptr, input_len + 1, null) != c.napi_ok) {
        rejectPromise(env, deferred, "Failed to get content");
        return promise;
    }

    // Generate document
    const result = gen.generateDocument(format, input_buffer[0..input_len]) catch |err| {
        rejectPromise(env, deferred, @errorName(err));
        return promise;
    };
    defer gen.allocator.free(result);

    // Create Node.js Buffer
    var buffer: c.napi_value = undefined;
    if (c.napi_create_buffer_copy(env, result.len, result.ptr, null, &buffer) != c.napi_ok) {
        rejectPromise(env, deferred, "Failed to create buffer");
        return promise;
    }

    _ = c.napi_resolve_deferred(env, deferred, buffer);
    return promise;
}

fn rejectPromise(env: c.napi_env, deferred: c.napi_deferred, message: []const u8) void {
    var error_msg: c.napi_value = undefined;
    _ = c.napi_create_string_utf8(env, message.ptr, message.len, &error_msg);
    _ = c.napi_reject_deferred(env, deferred, error_msg);
}

export fn init(_: c.napi_env, _: c.napi_callback_info) c.napi_value {
    if (is_initialized.load(.seq_cst)) {
        return null; // Already initialized
    }

    const allocator = std.heap.page_allocator;
    const config = Config.init();
    
    generator_instance = DocumentGenerator.init(allocator, config) catch {
        return null;
    };

    // Set generator instance in storage
    GeneratorStorage.set(generator_instance);
    
    // Set initialization flag atomically
    is_initialized.store(true, .seq_cst);
    return null;
}

// แก้ไข generatePDF function
export fn generatePDF(env: c.napi_env, info: c.napi_callback_info) c.napi_value {
    if (!is_initialized.load(.seq_cst)) {
        return null;
    }

    if (generator_instance) |gen| {
        // Get input string from JavaScript
        var argc: usize = 1;
        var args: [1]c.napi_value = undefined;
        if (c.napi_get_cb_info(env, info, &argc, &args, null, null) != c.napi_ok) {
            return null;
        }

        // Get string length
        var str_len: usize = undefined;
        if (c.napi_get_value_string_utf8(env, args[0], null, 0, &str_len) != c.napi_ok) {
            return null;
        }

        // Allocate buffer and get string content
        const input = gen.allocator.alloc(u8, str_len + 1) catch {
            return null;
        };
        defer gen.allocator.free(input);

        if (c.napi_get_value_string_utf8(env, args[0], input.ptr, str_len + 1, null) != c.napi_ok) {
            return null;
        }

        // Generate document
        const result = gen.generateDocument(.PDF, input[0..str_len]) catch {
            return null;
        };
        defer gen.allocator.free(result);

        // Create Node.js Buffer from result
        var buffer: c.napi_value = undefined;
        if (c.napi_create_buffer_copy(env, result.len, result.ptr, null, &buffer) != c.napi_ok) {
            return null;
        }

        return buffer;
    }
    
    return null;
}

// แก้ไข generateExcel function
export fn generateExcel(env: c.napi_env, info: c.napi_callback_info) c.napi_value {
     if (!is_initialized.load(.seq_cst)) {
        const err = createError(env, "Generator not initialized");
        _ = c.napi_throw(env, err);
        return null;
    }

    var argc: usize = 1;
    var args: [1]c.napi_value = undefined;
    if (c.napi_get_cb_info(env, info, &argc, &args, null, null) != c.napi_ok) {
        const err = createError(env, "Failed to parse arguments");
        _ = c.napi_throw(env, err);
        return null;
    }

    // ตรวจสอบ input
    var str_len: usize = undefined;
    if (c.napi_get_value_string_utf8(env, args[0], null, 0, &str_len) != c.napi_ok) {
        const err = createError(env, "Invalid input");
        _ = c.napi_throw(env, err);
        return null;
    }

    if (str_len == 0) {
        const err = createError(env, "Empty input");
        _ = c.napi_throw(env, err);
        return null;
    }

    // แปลง input เป็น string
    const input = generator_instance.?.allocator.alloc(u8, str_len + 1) catch {
        const err = createError(env, "Memory allocation failed");
        _ = c.napi_throw(env, err);
        return null;
    };
    defer generator_instance.?.allocator.free(input);

    if (c.napi_get_value_string_utf8(env, args[0], input.ptr, str_len + 1, null) != c.napi_ok) {
        const err = createError(env, "Failed to get input string");
        _ = c.napi_throw(env, err);
        return null;
    }

    // สร้าง Excel
    const result = generator_instance.?.generateDocument(.Excel, input[0..str_len]) catch |err| {
        const error_msg = switch (err) {
            GenerateError.ProcessError => "Process error",
            GenerateError.TimeoutError => "Timeout error",
            else => "Unknown error",
        };
        const error_obj = createError(env, error_msg);
        _ = c.napi_throw(env, error_obj);
        return null;
    };
    defer generator_instance.?.allocator.free(result);

    // สร้าง Buffer
    var buffer: c.napi_value = undefined;
    if (c.napi_create_buffer_copy(env, result.len, result.ptr, null, &buffer) != c.napi_ok) {
        const err = createError(env, "Failed to create buffer");
        _ = c.napi_throw(env, err);
        return null;
    }

    return buffer;
}

fn createError(env: c.napi_env, message: []const u8) c.napi_value {
    var msg_value: c.napi_value = undefined;
    var result: c.napi_value = undefined;
    
    // สร้าง napi_value สำหรับข้อความ error
    _ = c.napi_create_string_utf8(env, message.ptr, message.len, &msg_value);
    
    // สร้าง error object
    _ = c.napi_create_error(env, null, msg_value, &result);
    
    return result;
}
