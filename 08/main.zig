const std = @import("std");
usingnamespace @import("utils");

const Interpreter = struct {
    pub const Instruction = struct {
        pub const Operation = enum {
            acc,
            jmp,
            nop,
        };

        opcode: Operation,
        arg1: i64,

        pub fn parse(line: []const u8) !Instruction {
            const split = try splitOne(line, " ");
            const arg1 = try parseIntSigned(split[1], 10);

            inline for (std.meta.fields(Operation)) |field| {
                if (mem.eql(u8, field.name, split[0])) {
                    return Instruction{
                        .opcode = @field(Operation, field.name),
                        .arg1 = arg1,
                    };
                }
            }

            unreachable;
        }
    };

    lines: []u8,
    instructions: []Instruction,
    ipstack: []usize,
    accstack: []i64,
    ns: usize = 0,

    rip: usize = 0,
    accumulator: i64 = 0,

    pub fn preinit(chunks: []const []const u8) ![]Instruction {
        const instructions = try allocator.alloc(Instruction, chunks.len);
        for (instructions) |*c, i| {
            c.* = try Instruction.parse(chunks[i]);
        }

        return instructions;
    }

    pub fn init(instructions: []Instruction) !Interpreter {
        const lines = try allocator.alloc(u8, instructions.len);
        for (lines) |*c| {
            c.* = 0;
        }

        const ipstack = try allocator.alloc(usize, instructions.len);
        for (ipstack) |*c| {
            c.* = 0;
        }

        const accstack = try allocator.alloc(i64, instructions.len);
        for (accstack) |*c| {
            c.* = 0;
        }

        return Interpreter{
            .lines = lines,
            .instructions = instructions,
            .ipstack = ipstack,
            .accstack = accstack,
        };
    }

    pub fn can_step(self: *Interpreter) bool {
        return self.rip < self.instructions.len and
            self.lines[self.rip] == 0;
    }

    pub fn step(self: *Interpreter) void {
        self.lines[self.rip] += 1;

        const inst = self.instructions[self.rip];

        switch (inst.opcode) {
            .acc => {
                self.accumulator += inst.arg1;
                self.rip += 1;
            },
            .jmp => {
                self.rip +%= @intCast(usize, inst.arg1);
            },
            .nop => {
                self.rip += 1;
            },
        }
    }

    pub fn push(self: *Interpreter) void {
        const inst = self.instructions[self.rip];

        switch (inst.opcode) {
            .jmp, .nop => {
                self.ipstack[self.ns] = self.rip;
                self.accstack[self.ns] = self.accumulator;
                self.ns += 1;
            },
            else => {}
        }
    }

    pub fn pop(self: *Interpreter) void {
        self.ns -= 1;
        self.rip = self.ipstack[self.ns];
        self.accumulator = self.accstack[self.ns];
    }

    pub fn swapJmpNop(self: *Interpreter) void {
        const inst = self.instructions[self.rip];
        switch (inst.opcode) {
            .nop => {
                self.instructions[self.rip].opcode = .jmp;
            },
            .jmp => {
                self.instructions[self.rip].opcode = .nop;
            },
            else => {}
        }
    }
};

pub fn main() !void {
    try Benchmark.init();

    const input = try getFileSlice("08/input.txt");
    const inputs = try splitOne(input, "\n");

    Benchmark.read().print("File");
    Benchmark.reset();

    const instructions = try Interpreter.preinit(inputs);

    Benchmark.read().print("Initialization");
    Benchmark.reset();

    var total1: i64 = 0;
    var total2: i64 = 0;

    var vm = try Interpreter.init(instructions);
    while (vm.can_step()) {
        vm.push();
        vm.step();
    }

    total1 = vm.accumulator;

    Benchmark.read().print("Part 1");
    Benchmark.reset();

    const winner: usize = vm.instructions.len;
    while (vm.rip != winner) {
        vm.pop();
        vm.swapJmpNop();
        vm.step();
        while (vm.can_step()) {
            vm.step();
        }
    }

    total2 = vm.accumulator;

    Benchmark.read().print("Part 2");
    Benchmark.reset();

    std.debug.print("P1: {}\n", .{total1});
    std.debug.print("P2: {}\n", .{total2});
}
