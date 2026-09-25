// GPU point stream contract: two RGBA32F texels per point and segment.
// Segment: previous/start/end/next indices; flags/start-distance/end-distance/path-length.
uniform sampler2D mold_gpu_points : filter_nearest, repeat_disable;
uniform sampler2D mold_gpu_segments : filter_nearest, repeat_disable;
uniform int mold_gpu_vertices_per_segment = 12;
uniform int mold_gpu_join = 0;
uniform int mold_gpu_cap = 0;
uniform float mold_gpu_miter_limit = 4.0;
vec4 mold_gpu_fetch(sampler2D data, int index) {
    int width = textureSize(data, 0).x;
    return texelFetch(data, ivec2(index % width, index / width), 0);
}
vec2 mold_gpu_dir(vec2 delta, vec2 fallback) {
    float size = length(delta);
    return size > 0.00001 ? delta / size : fallback;
}
vec2 mold_gpu_normal(vec2 direction) { return vec2(-direction.y, direction.x); }
float mold_gpu_cross(vec2 a, vec2 b) { return a.x*b.y-a.y*b.x; }
vec2 mold_gpu_outline(vec2 incoming, vec2 outgoing, vec2 normal, float side,
        float radius, float neighbor, bool endpoint) {
    if (endpoint || (mold_gpu_join != 0 && mold_gpu_cross(incoming,outgoing)*side < 0.0))
        return normal * side * radius;
    vec2 sum = mold_gpu_normal(incoming) + mold_gpu_normal(outgoing);
    float denominator = dot(sum, mold_gpu_normal(outgoing));
    if (abs(denominator) < 0.00001) return normal * side * radius;
    vec2 offset = sum * (side * radius / denominator);
    float limit = min(radius * mold_gpu_miter_limit, neighbor * 0.5 + radius);
    return length(offset) > limit ? normalize(offset)*limit : offset;
}
// Produces the same analytic attributes consumed by the cached CPU stroke shader.
void mold_gpu_vertex(int vertex_id, out vec3 position, out vec4 color, out vec2 uv,
        out vec4 custom0, out vec4 custom1, out vec4 custom2) {
    int segment = vertex_id / mold_gpu_vertices_per_segment;
    int local_id = vertex_id % mold_gpu_vertices_per_segment;
    ivec4 indices = ivec4(round(mold_gpu_fetch(mold_gpu_segments, segment*2)));
    vec4 metrics = mold_gpu_fetch(mold_gpu_segments, segment*2+1);
    int flags = int(round(metrics.x));
    bool first = (flags & 1) != 0;
    bool last = (flags & 2) != 0;
    vec4 previous = mold_gpu_fetch(mold_gpu_points, indices.x*2);
    vec4 a = mold_gpu_fetch(mold_gpu_points, indices.y*2);
    vec4 b = mold_gpu_fetch(mold_gpu_points, indices.z*2);
    vec4 next = mold_gpu_fetch(mold_gpu_points, indices.w*2);
    vec2 direction = mold_gpu_dir(b.xy-a.xy, vec2(1.0,0.0));
    vec2 incoming = first ? direction : mold_gpu_dir(a.xy-previous.xy,direction);
    vec2 outgoing = last ? direction : mold_gpu_dir(next.xy-b.xy,direction);
    vec2 normal = mold_gpu_normal(direction);
    float segment_length = length(b.xy-a.xy);
    float progress = metrics.y / max(metrics.w,0.00001);
    int point_index = indices.y;
    position = a.xyz;
    uv = vec2(progress,0.5);
    custom0 = vec4(0.0,0.0,0.0,max(a.w*0.5,0.00001));
    custom1 = vec4(0.0); custom2 = vec4(0.0);
    int corners[6] = int[6](0,1,2,0,2,3);
    if (local_id < 12) {
        float side = local_id < 6 ? 1.0 : -1.0;
        int corner_id = local_id % 6;
        if (side < 0.0) { if (corner_id % 3 == 1) corner_id += 1; else if (corner_id % 3 == 2) corner_id -= 1; }
        int corner = corners[corner_id];
        bool at_start = corner < 2;
        bool outline = corner == 1 || corner == 2;
        vec4 current = at_start ? a : b;
        point_index = at_start ? indices.y : indices.z;
        float radius = max(current.w*0.5,0.00001);
        vec2 offset = vec2(0.0);
        if (outline) offset = at_start
            ? mold_gpu_outline(incoming,direction,normal,side,radius,min(length(a.xy-previous.xy),segment_length),first)
            : mold_gpu_outline(direction,outgoing,normal,side,radius,min(length(next.xy-b.xy),segment_length),last);
        vec2 start_shift = first && mold_gpu_cap == 1 ? -direction*a.w*0.5 : vec2(0.0);
        vec2 end_shift = last && mold_gpu_cap == 1 ? direction*b.w*0.5 : vec2(0.0);
        vec2 shift = at_start ? start_shift : end_shift;
        float line_length = segment_length + length(start_shift)+length(end_shift);
        bool start_cap = first && mold_gpu_cap != 2;
        bool end_cap = last && mold_gpu_cap != 2;
        vec2 extrusion = offset;
        if (at_start && start_cap) extrusion -= direction*radius;
        if (!at_start && end_cap) extrusion += direction*radius;
        float x = (at_start ? 0.0 : line_length)+dot(offset,direction);
        float y = dot(offset,normal)/radius;
        custom0 = vec4(extrusion,0.0,radius);
        custom1 = vec4(normal.x,y,start_cap ? 1.0-x/radius : 0.0,end_cap ? 1.0-(line_length-x)/radius : 0.0);
        custom2 = vec4(normal.y,dot(extrusion,normal)/radius,start_cap ? -dot(extrusion,direction)/radius : 0.0,end_cap ? dot(extrusion,direction)/radius : 0.0);
        position = current.xyz+vec3(offset+shift,0.0);
        progress = clamp((at_start ? metrics.y : metrics.z)+dot(offset,direction),metrics.y,metrics.z)/max(metrics.w,0.00001);
        uv = vec2(progress,0.5-y*0.5);
    } else {
        bool at_start = local_id < 24;
        int decoration_id = (local_id-12) % 12;
        vec4 current = at_start ? a : b;
        point_index = at_start ? indices.y : indices.z;
        position = current.xyz;
        float radius = max(current.w*0.5,0.00001);
        bool endpoint = at_start ? first : last;
        bool active = endpoint ? mold_gpu_cap == 2 : at_start && mold_gpu_join != 0;
        float turn = mold_gpu_cross(incoming,direction);
        float side = turn > 0.0 ? -1.0 : 1.0;
        vec2 from = endpoint ? (at_start ? normal : -normal) : mold_gpu_normal(incoming)*side;
        vec2 to = endpoint ? -from : normal*side;
        vec2 offset = vec2(0.0);
        bool round_join = endpoint || mold_gpu_join == 2;
        if (active && (endpoint || abs(turn)>0.00001)) {
            if (round_join) {
                float start_angle = atan(from.y,from.x);
                float delta = endpoint ? 3.14159265359 : atan(mold_gpu_cross(from,to),dot(from,to));
                int steps = abs(delta) > 1.57080632679 ? 2 : 1;
                int step_id = decoration_id/6;
                if (step_id < steps) {
                    float angle_a = start_angle+delta*float(step_id)/float(steps);
                    float angle_b = start_angle+delta*float(step_id+1)/float(steps);
                    int corner_id = decoration_id%6;
                    if (delta > 0.0) { if (corner_id%3==1) corner_id+=1; else if (corner_id%3==2) corner_id-=1; }
                    int corner = corners[corner_id];
                    if (corner==1) offset=vec2(cos(angle_a),sin(angle_a));
                    if (corner==2) offset=vec2(cos((angle_a+angle_b)*0.5),sin((angle_a+angle_b)*0.5))/cos((angle_b-angle_a)*0.5);
                    if (corner==3) offset=vec2(cos(angle_b),sin(angle_b));
                }
                custom1=vec4(offset,0.0,0.0); custom2=custom1;
            } else {
                int corner=decoration_id;
                if (turn > 0.0) { if(corner==1) corner=2; else if(corner==2) corner=1; }
                if(corner==1) offset=from; else if(corner==2) offset=to;
                vec2 axis=mold_gpu_dir(from+to,normal);
                vec2 bevel_axis=axis/max(dot(axis,from),0.00001);
                custom1=vec4(0.0,dot(offset,bevel_axis),0.0,0.0); custom2=custom1;
            }
        }
        custom0=vec4(offset*radius,round_join ? 2.0 : 1.0,radius);
        position+=vec3(offset*radius,0.0);
        progress=(at_start ? metrics.y : metrics.z)/max(metrics.w,0.00001);
        uv=vec2(progress,0.5-(length(offset)>0.00001 ? dot(normalize(offset),normal)*0.5 : 0.0));
    }
    color=mold_gpu_fetch(mold_gpu_points,point_index*2+1);
}
