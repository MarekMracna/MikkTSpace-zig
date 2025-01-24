const c = @cImport({
    @cInclude("mikktspace.h");
});
const std = @import("std");

const MTSCtx = c.SMikkTSpaceContext;
const MTSIFace = c.SMikkTSpaceInterface;

fn check(comptime T: type, comptime decl: []const u8, comptime F: type) void {
    if (!@hasDecl(T, decl)) {
        @compileError(std.fmt.comptimePrint(
            "{s} must have a {s} function",
            .{ @typeName(T), decl },
        ));
    }
    const f: F = @field(T, decl);
    _ = f;
}

fn interface(comptime Context: type) MTSIFace {
    comptime check(Context, "getNumFaces", fn (*Context) u32);
    comptime check(Context, "getNumVerticesOfFace", fn (*Context, u32) u32);
    comptime check(Context, "getPosition", fn (*Context, u32, u32) [3]f32);
    comptime check(Context, "getNormal", fn (*Context, u32, u32) [3]f32);
    comptime check(Context, "getTexCoord", fn (*Context, u32, u32) [2]f32);
    if (!@hasDecl(Context, "setTSpace")) {
        @compileError(std.fmt.comptimePrint(
            "{s} must have a setTSpace function",
            .{@typeName(Context)},
        ));
    }
    const basic = comptime blk: {
        const f = @typeInfo(@TypeOf(Context.setTSpace)).@"fn";
        break :blk f.params.len == 5;
    };
    const SetTSpaceBasic = fn (
        ctx: *Context,
        tangent: [3]f32,
        sign: f32,
        face: u32,
        vert: u32,
    ) void;
    const SetTSpace = fn (
        ctx: *Context,
        tangent: [3]f32,
        bitangent: [3]f32,
        mag_s: f32,
        mag_t: f32,
        is_orientation_preserving: bool,
        face: u32,
        vert: u32,
    ) void;
    const SetTSpaceFn = if (basic) SetTSpaceBasic else SetTSpace;
    comptime check(Context, "setTSpace", SetTSpaceFn);

    const Closure = struct {
        pub fn getNumFaces(mts_ctx_opt: [*c]const MTSCtx) callconv(.c) c_int {
            const mts_ctx: *const MTSCtx = @ptrCast(mts_ctx_opt);
            const ctx: *Context = @alignCast(@ptrCast(mts_ctx.m_pUserData));
            return @intCast(ctx.getNumFaces());
        }
        pub fn getNumVerticesOfFace(mts_ctx_opt: [*c]const MTSCtx, iface: c_int) callconv(.c) c_int {
            const mts_ctx: *const MTSCtx = @ptrCast(mts_ctx_opt);
            const ctx: *Context = @alignCast(@ptrCast(mts_ctx.m_pUserData));
            return @intCast(ctx.getNumVerticesOfFace(@intCast(iface)));
        }
        pub fn getPosition(mts_ctx_opt: [*c]const MTSCtx, pos_out: [*c]f32, iface: c_int, ivert: c_int) callconv(.c) void {
            const mts_ctx: *const MTSCtx = @ptrCast(mts_ctx_opt);
            const ctx: *Context = @alignCast(@ptrCast(mts_ctx.m_pUserData));
            const pos = ctx.getPosition(@intCast(iface), @intCast(ivert));
            pos_out[0] = pos[0];
            pos_out[1] = pos[1];
            pos_out[2] = pos[2];
        }
        pub fn getNormal(mts_ctx_opt: [*c]const MTSCtx, norm_out: [*c]f32, iface: c_int, ivert: c_int) callconv(.c) void {
            const mts_ctx: *const MTSCtx = @ptrCast(mts_ctx_opt);
            const ctx: *Context = @alignCast(@ptrCast(mts_ctx.m_pUserData));
            const norm = ctx.getNormal(@intCast(iface), @intCast(ivert));
            norm_out[0] = norm[0];
            norm_out[1] = norm[1];
            norm_out[2] = norm[2];
        }
        pub fn getTexCoord(mts_ctx_opt: [*c]const MTSCtx, texc_out: [*c]f32, iface: c_int, ivert: c_int) callconv(.c) void {
            const mts_ctx: *const MTSCtx = @ptrCast(mts_ctx_opt);
            const ctx: *Context = @alignCast(@ptrCast(mts_ctx.m_pUserData));
            const texc = ctx.getTexCoord(@intCast(iface), @intCast(ivert));
            texc_out[0] = texc[0];
            texc_out[1] = texc[1];
        }
        pub fn setTSpaceBasic(mts_ctx_opt: [*c]const MTSCtx, tang: [*c]const f32, sign: f32, iface: c_int, ivert: c_int) callconv(.c) void {
            const mts_ctx: *const MTSCtx = @ptrCast(mts_ctx_opt);
            const ctx: *Context = @alignCast(@ptrCast(mts_ctx.m_pUserData));
            ctx.setTSpace(tang[0..3].*, sign, @intCast(iface), @intCast(ivert));
        }
        pub fn setTSpace(mts_ctx_opt: [*c]const MTSCtx, tang: [*c]const f32, bitang: [*c]f32, mag_s: f32, mag_t: f32, is_orientation_preserving: c.tbool, iface: c_int, ivert: c_int) callconv(.c) void {
            const mts_ctx: *const MTSCtx = @ptrCast(mts_ctx_opt);
            const ctx: *Context = @alignCast(@ptrCast(mts_ctx.m_pUserData));
            ctx.setTSpace(
                tang[0..3].*,
                bitang[0..3].*,
                mag_s,
                mag_t,
                1 == is_orientation_preserving,
                @intCast(iface),
                @intCast(ivert),
            );
        }
    };

    return .{
        .m_getNumFaces = &Closure.getNumFaces,
        .m_getNumVerticesOfFace = &Closure.getNumVerticesOfFace,
        .m_getPosition = &Closure.getPosition,
        .m_getNormal = &Closure.getNormal,
        .m_getTexCoord = &Closure.getTexCoord,
        .m_setTSpaceBasic = if (basic) &Closure.setTSpaceBasic else null,
        .m_setTSpace = if (basic) null else &Closure.setTSpace,
    };
}

pub fn genTangSpaceDefault(context: anytype) bool {
    var mts_iface = interface(@TypeOf(context.*));
    var mts_ctx = MTSCtx{
        .m_pInterface = &mts_iface,
        .m_pUserData = context,
    };
    return 1 == c.genTangSpaceDefault(&mts_ctx);
}

pub fn genTangSpace(context: anytype, angular_threshold: f32) bool {
    var mts_iface = interface(@TypeOf(context.*));
    var mts_ctx = MTSCtx{
        .m_pInterface = &mts_iface,
        .m_pUserData = context,
    };
    return 1 == c.genTangSpace(&mts_ctx, angular_threshold);
}
