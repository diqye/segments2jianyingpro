//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const json = std.json;
const testing = std.testing;
const debug = std.debug;


const Jianying = struct {
    arena: std.heap.ArenaAllocator,
    draftPath: [] const u8,
    dir: ?std.fs.Dir = null,
    dir_path: ?[] const u8 = null,
    template: ?json.ObjectMap = null,
    root: ?json.ObjectMap = null,


    const Self = @This();
    const Timerange = struct {
        duration: i64,
        start: i64
    };
    pub const Audio = struct {
        path: [] const u8,
        id: [] const u8,
        segment_id: [] const u8,
        duration: i64,
        local_material_id: [] const u8,
        speed: f16 = 1,
        target_timerange: Timerange
    };
    pub const Video = struct {
        path: [] const u8,
        id: [] const u8,
        segment_id: [] const u8,
        local_material_id: [] const u8,
        speed: f16 = 1,
        duration: i64,
        width: u16,
        target_timerange: Timerange,
    };
    pub const Text = struct {
        font_path: [] const u8,
        text: [] const u8,
        id: [] const u8,
        segment_id: [] const u8,
        target_timerange: Timerange,
    };


    pub fn init(allocator: std.mem.Allocator) !Self {
        const home = try std.process.getEnvVarOwned(allocator, "HOME");
        defer allocator.free(home);
        var arena = std.heap.ArenaAllocator.init(allocator);
        const draftPath = try std.fmt.allocPrint(arena.allocator(), "{s}/Movies/JianyingPro/User Data/Projects/com.lveditor.draft", .{home});
        // const draftPath = try std.fmt.allocPrint(arena.allocator(), "{s}/Movies/CapCut/User Data/Projects/com.lveditor.draft", .{home});
        return .{
            .arena = arena,
            .draftPath = draftPath,
        };
    }

    pub fn append_text_in_all(self: *Self, text: Text) !void {
        const v = &self.template.?.getPtr("materials").?.object.getPtr("texts").?.array.items[0];
        var text_object = try v.object.clone();
        try text_object.put("id", .{.string = text.id});
        try text_object.put("font_path", .{.string = text.font_path});
        const content = text_object.getPtr("content").?;
        // 处理字幕
        content.string =  a: {
            var parsed: json.Parsed(json.Value) = try json.parseFromSlice(json.Value, self.arena.allocator(), content.string, .{});
            defer parsed.deinit();

            var value = parsed.value;
            try value.object.put("text", .{
                .string = text.text
            });
            var str_buf = std.ArrayList(u8).init(self.arena.allocator());
            defer str_buf.deinit();
            try json.stringify(value, .{}, str_buf.writer());

            break :a try self.arena.allocator().dupe(u8, str_buf.items);
        };
        
        try self.root.?.getPtr("materials").?.object.getPtr("texts").?.array.append(.{
            .object = text_object,
        });

        var track = findX(&self.root.?,"text").?;
        const templateTrack = findX(&self.template.?, "text").?;

        var text_track_segment = try templateTrack.object.getPtr("segments").?.array.items[0].object.clone();
        
        try text_track_segment.put("id", .{.string = text.segment_id});
        try text_track_segment.put("material_id", .{.string = text.id});

        
        const target_timerange = text_track_segment.getPtr("target_timerange").?;
        target_timerange.object = try target_timerange.object.clone();

        try target_timerange.object.put("duration", .{.integer = text.target_timerange.duration});
        try target_timerange.object.put("start", .{.integer = text.target_timerange.start});

        try track.object.getPtr("segments").?.array.append(json.Value{
            .object = text_track_segment
        });
    }
    pub fn append_audio_in_all(self: *Self, audio: Audio) !void {
        const v = &self.template.?.getPtr("materials").?.object.getPtr("audios").?.array.items[0];
        var audio_object = try v.object.clone();
        try audio_object.put("id", .{.string = audio.id});
        try audio_object.put("local_material_id", .{.string = audio.local_material_id});
        try audio_object.put("path", .{.string = audio.path});
        try audio_object.put("duration", .{.integer = audio.duration});
        
        try self.root.?.getPtr("materials").?.object.getPtr("audios").?.array.append(.{
            .object = audio_object
        });
        var track = findX(&self.root.?,"audio").?;
        const templateTrack = findX(&self.template.?, "audio").?;

        var audio_track_segment = try templateTrack.object.getPtr("segments").?.array.items[0].object.clone();
        
        try audio_track_segment.put("id", .{.string = audio.segment_id});
        try audio_track_segment.put("material_id", .{.string = audio.id});
        try audio_track_segment.put("speed", .{.float = audio.speed});

        const source_timerange = audio_track_segment.getPtr("source_timerange").?;
        // clone一份 objectmap,防止篡改template中的数据
        source_timerange.object = try source_timerange.object.clone();

        try source_timerange.object.put("duration", .{.integer = audio.duration});
        
        const target_timerange = audio_track_segment.getPtr("target_timerange").?;
        target_timerange.object = try target_timerange.object.clone();

        try target_timerange.object.put("duration", .{.integer = audio.target_timerange.duration});
        try target_timerange.object.put("start", .{.integer = audio.target_timerange.start});

        try track.object.getPtr("segments").?.array.append(json.Value{
            .object = audio_track_segment
        });
    }
    pub fn append_video_in_all(self: *Self, video: Video) !void {
        const v = &self.template.?.getPtr("materials").?.object.getPtr("videos").?.array.items[0];
        var video_object = try v.object.clone();
        try video_object.put("id", .{.string = video.id});
        try video_object.put("local_material_id", .{.string = video.local_material_id});
        try video_object.put("path", .{.string = video.path});
        try video_object.put("duration", .{.integer = video.duration});
        
        try self.root.?.getPtr("materials").?.object.getPtr("videos").?.array.append(.{
            .object = video_object
        });

        // 处理倍速
        var speed = json.ObjectMap.init(self.arena.allocator());
        try speed.put("curve_speed", .null);
        try speed.put("id", .{
            .string = try lib.generateUniqueId(self.arena.allocator(), 10)
        });
        try speed.put("mode", .{
            .integer = 0
        });
        try speed.put("speed", .{
            .float = video.speed
        });
        try speed.put("type", .{.string = "speed"});
        try self.root.?.getPtr("materials").?.object.getPtr("speeds").?.array.append(.{
            .object = speed,
        });

        // 处理 track segment
        var track = findX(&self.root.?,"video").?;
        const templateTrack = findX(&self.template.?, "video").?;
        var video_track_segment = try templateTrack.object.getPtr("segments").?.array.items[0].object.clone();
        
        try video_track_segment.put("id", .{.string = video.segment_id});
        try video_track_segment.put("material_id", .{.string = video.id});
        try video_track_segment.put("speed", .{.float = video.speed});
        var list = json.Array.init(self.arena.allocator());
        try list.append(.{.string = speed.getPtr("id").?.string});
        try video_track_segment.put("extra_material_refs", json.Value{
            .array = list
        });
        const source_timerange: * json.Value = video_track_segment.getPtr("source_timerange").?;
        
        // clone一份 objectmap,防止篡改template中的数据
        source_timerange.object = try source_timerange.object.clone();

        try source_timerange.object.put("duration", .{.integer = video.duration});
        
        const target_timerange = video_track_segment.getPtr("target_timerange").?;
        target_timerange.object = try target_timerange.object.clone();

        try target_timerange.object.put("duration", .{.integer = video.target_timerange.duration});
        try target_timerange.object.put("start", .{.integer = video.target_timerange.start});

        try track.object.getPtr("segments").?.array.append(json.Value{
            .object = video_track_segment
        });

    }

    pub fn create(self: *Self,name: [] const u8) !void {
        var dir = try std.fs.openDirAbsolute(self.draftPath, .{});
        defer dir.close();
        dir.makeDir(name) catch |err| switch(err) {
            error.PathAlreadyExists => {
                try dir.deleteTree(name);
                try dir.makeDir(name);
            },
            else => { 
                std.debug.print("{s},{}\n\n", .{name,err});
                @panic("创建文件夹出错");
            }
        };
        self.dir = try dir.openDir(name, .{});
        const dir_path = try std.fs.path.join(self.arena.allocator(), &.{
            self.draftPath,
            name
        });
        self.dir_path = dir_path;
        try self.prepare_info();
    }

    pub fn done(self: *Self) !void {
        try self.put_meta_info();
        var file = try self.dir.?.createFile("draft_info.json", .{.truncate = true});
        defer file.close();
        try json.stringify(json.Value{.object = self.root.?}, .{
            // .whitespace = .indent_2
        }, file.writer());
    }

    pub fn print_root(self: *Self) !void {
        (json.Value{
            .object =  self.root.?
        }).dump();
        try std.io.getStdOut().writer().print("\n\n", .{});
    }
    fn put_draft_settings(self: *Self) !void {
        @compileLog("已过期，无需使用我");
        const raw = @embedFile("asserts/draft_settings");
        var file = try self.dir.?.createFile("draft_settings", .{.truncate = true});
        defer file.close();
        try file.writeAll(raw);
    }
    
    fn put_template(self: *Self) !void {
        @compileLog("已过期，无需使用我");
        const row_template = @embedFile("asserts/template.tmp");
        const row_template_2 = @embedFile("asserts/template-2.tmp");
        var file = try self.dir.?.createFile("template.tmp", .{.truncate = true});
        var file2 = try self.dir.?.createFile("template-2.tmp", .{.truncate = true});
        defer {
            file.close();
            file2.close();
        }
        try file.writeAll(row_template);
        try file2.writeAll(row_template_2);
    }

    fn put_meta_info(self: *Self) !void {
        const raw = @embedFile("asserts/draft_meta_info.min.json");
        var file = try self.dir.?.createFile("draft_meta_info.json", .{.truncate = true});
        defer file.close();
        try file.writeAll(raw);
    }

    fn findX(object: *json.ObjectMap,name: [] const u8) ?*json.Value {
        for(object.getPtr("tracks").?.array.items) |*track| {
            if(std.mem.eql(u8, track.object.getPtr("type").?.string, name)) {
                return track; 
            }
        }
        return null;
    }
    /// 准备好一个模版
    /// 一个root 作为 draft_info.json 的根基
    fn prepare_info(self: *Self) !void {
        const allocator = self.arena.allocator();
        const row_json = @embedFile("asserts/draft_info.min.json");
        const obj : json.Parsed(json.Value)  = try json.parseFromSlice(json.Value, allocator, row_json, .{});

        self.template = obj.value.object;
        self.root = try obj.value.object.clone();

        var value = self.root.?;
        
        try value.put("id", .{.string = try lib.generateUniqueId(allocator,16)});

        const last_modified_platform = value.getPtr("last_modified_platform");
        
        const a = try lib.generateUniqueId(allocator,16);
        const b = try lib.generateUniqueId(allocator,16);
        const c2 = try lib.generateUniqueId(allocator,16);
        try last_modified_platform.?.object.put("device_id", .{.string = a});
        try last_modified_platform.?.object.put("hard_disk_id", .{.string = b});
        try last_modified_platform.?.object.put("mac_address", .{.string = c2});
        
        var platform = value.getPtr("platform").?;
        try platform.object.put("device_id", .{.string = a});
        try platform.object.put("hard_disk_id", .{.string = b});
        try platform.object.put("mac_address", .{.string = c2});

        const materials_obj = &self.root.?.getPtr("materials").?.object;
        materials_obj.* = try materials_obj.clone();        
        const audios = materials_obj.getPtr("audios").?;
        audios.* = json.Value{
            .array = json.Array.init(self.arena.allocator())
        };

        const videos = materials_obj.getPtr("videos").?;
        videos.* = json.Value{
            .array = json.Array.init(self.arena.allocator())
        };
        
        const speeds = materials_obj.getPtr("speeds").?;
        speeds.array = json.Array.init(self.arena.allocator());

        const texts = materials_obj.getPtr("texts").?;
        texts.array = json.Array.init(self.arena.allocator());

        const tracks = self.root.?.getPtr("tracks").?;
        tracks.* = .{
            .array = try tracks.array.clone()
        };
        for(self.root.?.getPtr("tracks").?.array.items) |*track|{
            track.* = .{
                .object = try track.object.clone()
            };
            const track_obj = &track.object;
            track_obj.getPtr("segments").?.* = .{ 
                .array = json.Array.init(self.arena.allocator()) 
            };
        }

    }

    pub fn deinit(self: *Self)  void {
        if(self.dir)|d|  {
            var dir = d;
            dir.close();
        }
        self.arena.deinit();
    }
    
};



const APIResult = struct {
    code: u16,
    data: struct {
        content: struct {
            concatVideos: [] struct {
                start: f32,
                end: f32,
                playbackRate: f16,
                video: [] const u8,
                loacal_path: [] u8 = "",
            },
            mixingAudios: [] struct {
                startInOutput: f32,
                endInoutput: f32,
                audio: [] const u8,
                loacal_path: [] u8 = "",
            },
            subtitles: [] const struct {
                text: [] const u8,
                endInoutput: f32,
                startInOutput: f32
            }
        },
        title: [] const u8 = "九霄",
    },
    message: [] const u8 = "",
    traceId: [] const u8 = ""
};

const FetchProps = struct {
    url : [] const u8,
    headers : [] const std.http.Header = &.{},
    method: std.http.Method = .GET
};
fn fetch(props:FetchProps,result: *std.ArrayList(u8)) !void {
    const allocator = std.heap.page_allocator;
    const default_headers = [_]std.http.Header{
        .{.name = "User-Agent", .value = "Zigclient/九霄"},
        .{.name = "Accpet", .value = "*/*"}
    };
    
    var headers = try allocator.alloc(std.http.Header, default_headers.len + props.headers.len);
    @memcpy(headers[0..default_headers.len], &default_headers);
    @memcpy(headers[default_headers.len..], props.headers);
    var client = std.http.Client {
        .allocator = allocator,
    };
    defer client.deinit();
    const status = try client.fetch(.{
        .method = props.method,
        .location = .{.url = props.url},
        .extra_headers = headers,
        .response_storage = .{.dynamic = result}
    });
    // std.debug.print("Fetch {s} {} {s}\n", .{props.url,@intFromEnum(status.status),@tagName(status.status)});
    if(status.status != .ok) {
        @panic("接口错误");
    }
}

const c = @cImport({
    @cInclude("curl/curl.h");
});
fn writeCallback(
    data: ?*anyopaque,
    size: usize,
    nmemb: usize,
    userptr: ?*anyopaque
) callconv(.C) usize {
    const total = size * nmemb;
    const file: *std.fs.File = @ptrCast(@alignCast(userptr));
    const src: [*]const u8 = @ptrCast(data.?);
    file.writeAll(src[0..total]) catch return 0;
    // _ = result_list.appendSlice(src[0..total]) catch return 0;
    return total;
}

fn download(url: [] const u8,dir: *std.fs.Dir) ![] const u8 {
    const allocator = std.heap.page_allocator;

    const curl = c.curl_easy_init() orelse return error.CurlInitFailed;
    defer c.curl_easy_cleanup(curl);

    c.curl_easy_reset(curl);
    // Slice 转换为 c_string
    const c_url = try allocator.dupeZ(u8, url);
    defer allocator.free(c_url);

    _ = c.curl_easy_setopt(curl,c.CURLOPT_URL, c_url.ptr);
    _ = c.curl_easy_setopt(curl,c.CURLOPT_HTTPGET, @as(c_long,1));
    _ = c.curl_easy_setopt(curl, c.CURLOPT_WRITEFUNCTION, writeCallback);
    // 开启verbose
    // _ = c.curl_easy_setopt(curl,c.CURLOPT_VERBOSE, @as(c_long,1));


    const name = std.fs.path.basename(url);
    var file = try dir.createFile(name, .{.truncate = true});
    defer file.close();
    _ = c.curl_easy_setopt(curl, c.CURLOPT_WRITEDATA, &file);

    const code = c.curl_easy_perform(curl);

    if(code != c.CURLE_OK) {
        return error.DownloadFailed;
    }


    // try file.writeAll(response_body.items);
    std.debug.print("Downloaded {s}", .{name});
    return name;
}


fn take_video_segments(allocator:std.mem.Allocator,token:[] const u8) !struct {
    parsed: json.Parsed(APIResult),
    _inner: std.ArrayList(u8),

    pub fn deinit(self: *@This()) void {
        self.parsed.deinit();
        self._inner.deinit();
    }
}{
    const api: [] const u8 = "https://test-jx-admin-api.zmexing.com/aiPlot/v1/videoklipMessage";
    var response_body = std.ArrayList(u8).init(allocator);

    const headers = [_]std.http.Header {
        .{.name = "JX-VEDIOKLIP-TOKEN", .value = token}
    };

    try fetch(.{ 
        .url = api,
        .headers = &headers,
        .method = .POST
    }, &response_body);

    return .{
        ._inner = response_body,
        .parsed = std.json.parseFromSlice(APIResult, allocator, response_body.items, .{.ignore_unknown_fields = true}) catch {
            var errorParsed:json.Parsed(json.Value) = try std.json.parseFromSlice(json.Value, allocator, response_body.items, .{});
            defer errorParsed.deinit();
            std.debug.print("{s}\n",.{errorParsed.value.object.getPtr("message").?.string});
            std.process.exit(0);
        },
    };
    
}

test "take" {
    const allocator = std.testing.allocator;
    var segment = try take_video_segments(allocator, "AAABo2hU/ypeOeNhaT8sb5snsbvCozyX");
    defer segment.deinit();

    std.debug.print("{s}\n", .{segment.parsed.value.data.content.concatVideos[0].video});
}


test "test" {
    const api: [] const u8 = "https://test-jx-admin-api.zmexing.com/aiPlot/v1/videoklipMessage";
    const current_path = "/Users/diqye/zigproject/jx2jy";

    const allocator = std.testing.allocator;
    var dir = std.fs.cwd();
    dir.makeDir("asserts") catch {};
    var subdir = try dir.openDir("asserts", .{ });

    const sub_abs_path = try std.fs.path.join(allocator, &.{
        current_path,
        "asserts"
    });
    defer allocator.free(sub_abs_path);

    var response_body = std.ArrayList(u8).init(allocator);
    defer response_body.deinit();

    const headers = [_]std.http.Header {
        .{.name = "JX-VEDIOKLIP-TOKEN", .value = "AAABo2hU/ypeOeNhaT8sb5snsbvCozyX"}
    };

    try fetch(.{ 
        .url = api,
        .headers = &headers,
        .method = .POST
    }, &response_body);

    var parsed : json.Parsed(APIResult) = try std.json.parseFromSlice(APIResult, allocator, response_body.items, .{.ignore_unknown_fields = true});
    defer parsed.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const allocatorB = arena.allocator();
    for(parsed.value.data.content.mixingAudios[0..1])|*audio| {
        const name = try download(audio.audio, &subdir);
        const path = try std.fs.path.join(allocatorB, &.{
            sub_abs_path,
            name,
        });
        audio.loacal_path = path;
    }
    
    var json_buf = std.ArrayList(u8).init(allocator);
    defer json_buf.deinit();

    // try json.stringify(parsed.value, .{}, json_buf.writer());
    std.debug.print("\n{s}\n", .{json_buf.items});
}
test "download" {
    
    // var dir = try std.fs.cwd().openDir("asserts", .{});
    // defer dir.close();
    // const Audio = struct {
    //     audio: [] const u8
    // };
    // const audios = [_]Audio{
    //     .{.audio = "https://static.zmexing.com/RD/audio/2025/6/16/93986628-77f2-4658-9b19-2ae8f90a1e46.mp3"},
    //     .{.audio = "https://static.zmexing.com/RD/audio/2025/6/16/9ba87c92-c7b1-4591-b221-1b7ed96535b5.mp3"}
    // };
    // for(&audios)|*audio| {
    //     const name = try download(audio.audio, &dir);
    //     std.debug.print("{s}\n", .{name});
    // }
}
test "fetch" {
    const allocator = std.testing.allocator;
    const api = "https://test-jx-admin-api.zmexing.com//aiPlot/v1/videoklipMessage";

    const headers = [_]std.http.Header {
        .{.name = "JX-VEDIOKLIP-TOKEN", .value = "AAABo2hU/ypeOeNhaT8sb5snsbvCozyX"}
    };

    var response_body = std.ArrayList(u8).init(allocator);
    defer response_body.deinit();

    try fetch(.{ 
        .url = api,
        .headers = &headers,
        .method = .POST
    }, &response_body);

    var parsed = try std.json.parseFromSlice(APIResult, allocator, response_body.items, .{.ignore_unknown_fields = true});
    defer parsed.deinit();


    std.debug.print("\n\n{s}\n", .{parsed.value.data.title});
}

test "start-jianying" {
    const allocator = std.testing.allocator;
    var jy = try Jianying.init(allocator);
    defer jy.deinit();
    const name = "hello-jiuxiao-2";
    try jy.create(name);

    const id,const local_id,const s_id = .{
        try lib.generateUniqueId(allocator,8),
        try lib.generateUniqueId(allocator,8),
        try lib.generateUniqueId(allocator,8),
    };
    defer {
        allocator.free(id);
        allocator.free(local_id);
        allocator.free(s_id);
    }
    try jy.append_audio_in_all(Jianying.Audio{
        .id = id,
        .local_material_id = local_id,
        .segment_id = s_id,
        .duration = 21.34 * 1000000,
        .path = "/Users/diqye/Movies/dufu.MP3",
        .speed = 1,
        .target_timerange = .{ 
            .duration = 21.34 * 1000000, 
            .start = 0
        }
    });

    const id2,const local_id2,const s_id2 = .{
        try lib.generateUniqueId(allocator,8),
        try lib.generateUniqueId(allocator,8),
        try lib.generateUniqueId(allocator,8),
    };
    defer {
        allocator.free(id2);
        allocator.free(local_id2);
        allocator.free(s_id2);
    }
    try jy.append_audio_in_all(Jianying.Audio{
        .id = id2,
        .local_material_id = local_id2,
        .segment_id = s_id2,
        .duration = 21.34 * 1000000,
        .path = "/Users/diqye/Movies/dufu.MP3",
        .speed = 1,
        .target_timerange = .{ 
            .duration = 2 * 21.34 * 1000000, 
            .start = 21.34 * 1000000
        }
    });

    // try jy.print_root();
    try jy.done();
    debug.print("name={s}\npath={s}\n", .{name,jy.draftPath});
}


test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("jx2jy_lib");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var arg = std.process.args();
    defer arg.deinit();
    const program_name = arg.next() orelse "";
    const token = arg.next() orelse "";

    if(std.mem.eql(u8, token, "")) {
        std.debug.print("请传入token\n\n示例: {s} token\n", .{program_name});
        std.process.exit(0);
    }

    var segment = try take_video_segments(allocator, token);
    defer segment.deinit();

    const data = &segment.parsed.value.data;
    var jy = try Jianying.init(allocator);
    defer jy.deinit();

    std.debug.print("创建工程:{s}\n", .{data.title});
    try jy.create(data.title);

    // 准备好下载媒体文件目
    const assert_dir_name = "jiuxiao-assert";
    jy.dir.?.makeDir(assert_dir_name) catch {};
    var assert_dir = try jy.dir.?.openDir(assert_dir_name,.{});
    defer assert_dir.close();
    const assert_dir_path = try std.fs.path.join(allocator, &.{
        jy.dir_path.?,
        assert_dir_name,
    });
    defer allocator.free(assert_dir_path);

    var buff_list = std.ArrayList([] const u8).init(allocator);
    defer {
        for(buff_list.items)|items| {
            allocator.free(items);
        }
        buff_list.deinit();
    }
    const micro_unit: f64 = 1000000;
    // 字幕
    {
        var start: i64 = 0;
        const len = data.content.subtitles.len;
        for (data.content.subtitles,1..) |*subtitle,i| {
            const progress:u8 = @intFromFloat(@as(f64,@floatFromInt(i)) / @as(f64,@floatFromInt(len)) * 100);
            std.debug.print("\x1b[2K\r字幕{d}/{d} {d}% {s}", .{i,len,progress,subtitle.text});
            const id1,const id2,const id3 = .{
                try lib.generateUniqueId(allocator,8),
                try lib.generateUniqueId(allocator,8),
                try lib.generateUniqueId(allocator,8),
            };
            try buff_list.append(id1);
            try buff_list.append(id2);
            try buff_list.append(id3);
            const duration : i64 = @intFromFloat(@as(f64,subtitle.endInoutput - subtitle.startInOutput) * micro_unit);
            try jy.append_text_in_all(Jianying.Text{
                .id = id1,
                .segment_id = id3,
                .font_path = "",
                .target_timerange = .{ 
                    .duration = duration,
                    .start =  start
                },
                .text = subtitle.text,
            });
            start += duration; 
        }
        std.debug.print("\n", .{});
    }
    // 音频
    {
        var start: i64 = 0;
        const len = data.content.mixingAudios.len;
        for (data.content.mixingAudios,1..) |audio,i| {
            const progress:u8 = @intFromFloat(@as(f64,@floatFromInt(i)) / @as(f64,@floatFromInt(len)) * 100);
            std.debug.print("\x1b[2K\rDownloading audios {d}/{d} {d}% ", .{i,len,progress});
            const name = try download(audio.audio, &assert_dir);
            const path = try std.fs.path.join(allocator, &.{
                assert_dir_path,
                name
            });
            try buff_list.append(path);
            const id1,const id2,const id3 = .{
                try lib.generateUniqueId(allocator,8),
                try lib.generateUniqueId(allocator,8),
                try lib.generateUniqueId(allocator,8),
            };
            try buff_list.append(id1);
            try buff_list.append(id2);
            try buff_list.append(id3);
            const duration : i64 = @intFromFloat(@as(f64,audio.endInoutput - audio.startInOutput) * micro_unit);
            try jy.append_audio_in_all(.{
                .duration = duration,
                .id = id1,
                .local_material_id = id2,
                .segment_id = id3,
                .path = path,
                .target_timerange = .{ 
                    .duration = duration,
                    .start =  start
                },
            });
            start += duration; 
        }
        std.debug.print("\n", .{});
    }
    // 视频
    {
        var start: i64 = 0;
        const len = data.content.concatVideos.len;
        for (data.content.concatVideos,1..) |*video,i| {
            const progress:u8 = @intFromFloat(@as(f64,@floatFromInt(i)) / @as(f64,@floatFromInt(len)) * 100);
            std.debug.print("\x1b[2K\rDownloading videos {d}/{d} {d}% ", .{i,len,progress});
            const name = try download(video.video, &assert_dir);
            const path = try std.fs.path.join(allocator, &.{
                assert_dir_path,
                name
            });
            try buff_list.append(path);
            const id1,const id2,const id3 = .{
                try lib.generateUniqueId(allocator,8),
                try lib.generateUniqueId(allocator,8),
                try lib.generateUniqueId(allocator,8),
            };
            try buff_list.append(id1);
            try buff_list.append(id2);
            try buff_list.append(id3);
            const duration : i64 = @intFromFloat(@as(f64,video.end - video.start) * micro_unit);
            try jy.append_video_in_all(.{
                .duration = @intFromFloat(@as(f64,@floatFromInt(duration)) * @as(f64,video.playbackRate)),
                .id = id1,
                .local_material_id = id2,
                .segment_id = id3,
                .path = path,
                .speed = video.playbackRate,
                .target_timerange = .{ 
                    .duration = duration,
                    .start =  start,
                },
                .width = 1920,
            });
            start += duration; 
        }
        std.debug.print("\n", .{});
    }
    // try jy.print_root();
    try jy.done();
    std.debug.print("完成，请打开剪映，打开工程“{s}”\n", .{data.title});

}