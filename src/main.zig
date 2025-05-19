const wgpu = @import("wgpu");
const std = @import("std");

pub fn main() !void {
    try collatz_example();
}

pub fn collatz_example() !void {
    const numbers = [_]u32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const numbers_size = @sizeOf(@TypeOf(numbers));
    //const numbers_size = 4;
    const numbers_length = numbers_size / @sizeOf(u32);

    const instance = wgpu.Instance.create(null).?;
    defer instance.release();

    const adapter_request = instance.requestAdapterSync(&wgpu.RequestAdapterOptions{});
    const adapter = switch (adapter_request.status) {
        .success => adapter_request.adapter.?,
        else => return error.NoAdapter,
    };
    defer adapter.release();

    const device_request = adapter.requestDeviceSync(&wgpu.DeviceDescriptor{
        .required_limits = null,
    });
    const device = switch (device_request.status) {
        .success => device_request.device.?,
        else => return error.NoDevice,
    };
    defer device.release();

    const queue = device.getQueue().?;
    defer queue.release();

    const shader_module = device.createShaderModule(&wgpu.shaderModuleWGSLDescriptor(.{
        .code = @embedFile("./collatz.wgsl"),
    })).?;
    defer shader_module.release();

    const staging_buffer = device.createBuffer(&wgpu.BufferDescriptor{
        .label = "staging_buffer",
        .usage = wgpu.BufferUsage.map_read | wgpu.BufferUsage.copy_dst,
        .size = numbers_size,
        .mapped_at_creation = @as(u32, @intFromBool(false)),
    }).?;
    defer staging_buffer.release();

    const storage_buffer = device.createBuffer(&wgpu.BufferDescriptor{
        .label = "storage_buffer",
        .usage = wgpu.BufferUsage.storage | wgpu.BufferUsage.copy_dst | wgpu.BufferUsage.copy_src,
        .size = numbers_size,
        .mapped_at_creation = @as(u32, @intFromBool(false)),
    }).?;
    defer storage_buffer.release();

    const compute_pipeline = device.createComputePipeline(&wgpu.ComputePipelineDescriptor{
        .label = "compute_pipeline",
        .compute = wgpu.ProgrammableStageDescriptor{
            .module = shader_module,
            .entry_point = "main",
        },
    }).?;
    defer compute_pipeline.release();

    const bind_group_layout = compute_pipeline.getBindGroupLayout(0).?;
    defer bind_group_layout.release();

    const bind_group = device.createBindGroup(&wgpu.BindGroupDescriptor{
        .label = "bind_group",
        .layout = bind_group_layout,
        .entry_count = 1,
        .entries = &[_]wgpu.BindGroupEntry{
            wgpu.BindGroupEntry{
                .binding = 0,
                .buffer = storage_buffer,
                .offset = 0,
                .size = numbers_size,
            },
        },
    }).?;
    defer bind_group.release();

    const command_encoder = device.createCommandEncoder(&wgpu.CommandEncoderDescriptor{
        .label = "command_encoder",
    }).?;
    defer command_encoder.release();

    const compute_pass_encoder = command_encoder.beginComputePass(&wgpu.ComputePassDescriptor{ .label = "compute_pass" }).?;
    defer compute_pass_encoder.release();

    compute_pass_encoder.setPipeline(compute_pipeline);
    compute_pass_encoder.setBindGroup(0, bind_group, 0, null);
    compute_pass_encoder.dispatchWorkgroups(numbers_length, 1, 1);
    compute_pass_encoder.end();
    compute_pass_encoder.release();

    command_encoder.copyBufferToBuffer(storage_buffer, 0, staging_buffer, 0, numbers_size);

    const command_buffer = command_encoder.finish(&wgpu.CommandBufferDescriptor{
        .label = "command_buffer",
    }).?;
    defer command_buffer.release();

    queue.writeBuffer(storage_buffer, 0, &numbers, numbers_size);
    queue.submit(&[_]*const wgpu.CommandBuffer{command_buffer});

    buffer_map_done = false;
    staging_buffer.mapAsync(wgpu.MapMode.read, 0, numbers_size, handle_buffer_map, null);
    _ = device.poll(true, null);

    //     // Wait for the mapping to complete with timeout
    var timeout_counter: u32 = 0;
    const max_timeout = 1000; // Try up to 1000 iterations

    while (!buffer_map_done and timeout_counter < max_timeout) {
        _ = device.poll(true, null);
        timeout_counter += 1;
        if (timeout_counter % 100 == 0) {
            std.debug.print("Waiting for buffer mapping... {d}/{d}\n", .{ timeout_counter, max_timeout });
        }
    }

    if (!buffer_map_done) {
        std.debug.print("[ERROR]:     Buffer mapping timed out!\n", .{});
        return;
    }

    std.debug.print("[INFO]:     Buffer mapped successfully after {d} iterations\n", .{timeout_counter});
    defer staging_buffer.unmap();

    const buf: [*]u8 = @ptrCast(staging_buffer.getMappedRange(0, numbers_size).?);

    // Cast the buffer to an array of u32 values
    const output = @as([*]const u32, @ptrCast(@alignCast(buf)))[0..numbers_length];

    std.debug.print("\nCollatz Numbers:\n{any}\n", .{output});
}

//This callback is called when the buffer mapping is complete
var buffer_map_done: bool = false;

fn handle_buffer_map(status: wgpu.BufferMapAsyncStatus, _: ?*anyopaque) callconv(.C) void {
    //std.debug.print("[INFO]:     Buffer map callback triggered with status: {s}\n", .{@tagName(status)});

    if (status == .success) {
        std.debug.print("[INFO]:     Buffer mapped successfully.\n", .{});
        buffer_map_done = true;
    } else {
        std.debug.print("[ERROR]:     Buffer mapping failed with status: {s}\n", .{@tagName(status)});
        // Set to true anyway so we don't get stuck in a loop
        buffer_map_done = true;
    }
}
