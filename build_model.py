"""Run with the installed Blender: blender --background --python build_model.py."""
from pathlib import Path
import math
import bpy
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "godot" / "assets"
ASSETS.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
model = bpy.data.collections.new("Golden Toilet")
bpy.context.scene.collection.children.link(model)


def material(name, color, metal=1.0, roughness=0.17):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = roughness
    return mat


gold = material("Polished 24K Gold", (0.83, 0.49, 0.075), roughness=0.145)
trim = material("Gold Edge Highlights", (0.94, 0.64, 0.18), roughness=0.115)
shadow_gold = material("Recessed Gold", (0.32, 0.17, 0.025), roughness=0.23)
rubber = material("Hinge and Lid Gaskets", (0.025, 0.020, 0.014), metal=0, roughness=0.40)


def register(obj, mat=gold):
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    model.objects.link(obj)
    if obj.type == "MESH":
        obj.data.materials.append(mat)
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def mesh(name, verts, faces, mat=gold):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    model.objects.link(obj)
    obj.data.materials.append(mat)
    for p in data.polygons:
        p.use_smooth = True
    return obj


def bevel(obj, width, segments=4):
    mod = obj.modifiers.new("Soft manufactured edges", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod = obj.modifiers.new("Weighted surface normals", "WEIGHTED_NORMAL")
    mod.keep_sharp = True
    return obj


def box(name, location, dimensions, radius, mat=gold):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = register(bpy.context.object, mat)
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel(obj, radius, 6)
    return obj


def cylinder(name, location, radius, depth, mat=gold, along_x=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=radius, depth=depth, location=location)
    obj = register(bpy.context.object, mat)
    obj.name = name
    if along_x:
        obj.rotation_euler[1] = math.pi / 2
    bevel(obj, min(0.002, depth / 5), 3)
    return obj


def surface(name, profiles, center_y=0, mat=gold, closed=True, subdiv=1):
    # Each profile is (half width, half depth, height); a continuous closed shell.
    n = 128
    verts = [(a * math.cos(t * 2 * math.pi / n), center_y + b * math.sin(t * 2 * math.pi / n), z)
             for a, b, z in profiles for t in range(n)]
    faces = []
    end = len(profiles) if closed else len(profiles) - 1
    for k in range(end):
        nxt = (k + 1) % len(profiles)
        for j in range(n):
            jj = (j + 1) % n
            faces.append((k*n+j, k*n+jj, nxt*n+jj, nxt*n+j))
    obj = mesh(name, verts, faces, mat)
    if subdiv:
        mod = obj.modifiers.new("Continuous curvature", "SUBSURF")
        mod.levels = subdiv
        mod.render_levels = subdiv
    return obj


# One continuous pedestal, including the rear skirt seen in the side references.
profiles = [
    (0.148, -0.380, 0.326, 0.006), (0.155, -0.385, 0.329, 0.014),
    (0.155, -0.384, 0.328, 0.030), (0.151, -0.377, 0.323, 0.075),
    (0.140, -0.337, 0.312, 0.155), (0.128, -0.275, 0.302, 0.225),
    (0.127, -0.210, 0.303, 0.270), (0.143, 0.020, 0.321, 0.319),
    (0.167, 0.132, 0.329, 0.367), (0.179, 0.166, 0.350, 0.408),
    (0.181, 0.169, 0.350, 0.419)]
n = 128
verts = []
for a, front, rear, z in profiles:
    c, b = (front + rear) / 2, (rear - front) / 2
    for j in range(n):
        t = j * 2 * math.pi / n
        co, si = math.cos(t), math.sin(t)
        verts.append((a * math.copysign(abs(co)**0.60, co), c + b * math.copysign(abs(si)**0.60, si), z))
faces = [(k*n+j, k*n+(j+1)%n, (k+1)*n+(j+1)%n, (k+1)*n+j)
         for k in range(len(profiles)-1) for j in range(n)]
faces += [tuple(reversed(range(n))), tuple((len(profiles)-1)*n+j for j in range(n))]
pedestal = mesh("Continuous Pedestal and Rear Skirt", verts, faces)
mod = pedestal.modifiers.new("Pedestal soft transitions", "SUBSURF")
mod.levels = mod.render_levels = 2

bowl = surface("Hollow Bowl", [
    (.071, .108, .240), (.096, .145, .243), (.124, .186, .254),
    (.155, .229, .274), (.180, .264, .304), (.200, .285, .345),
    (.211, .294, .385), (.214, .296, .413), (.214, .296, .426),
    (.213, .295, .432), (.208, .290, .436), (.200, .282, .436),
    (.177, .252, .436), (.168, .242, .431), (.165, .238, .419),
    (.161, .229, .399), (.150, .210, .372), (.132, .183, .342),
    (.108, .151, .318), (.077, .112, .300), (.044, .064, .289),
    (.023, .035, .286), (.022, .034, .276), (.036, .053, .270),
    (.054, .080, .248)], center_y=-.13, subdiv=2)

# The deck joins the tank to the bowl and conceals the pedestal top.
box("Rear Deck", (0, .245, .427), (.371, .226, .043), .017)
surface("Bowl Rim Accent", [(.214,.296,.414),(.216,.298,.417),(.216,.298,.429),(.214,.296,.432)], -.13, trim)

box("Tank Body", (0, .263, .611), (.373, .170, .335), .025)
box("Tank Lid Shadow Seam", (0, .263, .780), (.363, .166, .010), .016, rubber)
box("Tank Cap", (0, .263, .800), (.384, .181, .035), .016, trim)
cylinder("Flush Button Bezel", (0, .263, .822), .023, .008, trim)
cylinder("Flush Button", (0, .263, .827), .0195, .004)
box("Dual Flush Button Seam", (0, .263, .829), (.0008, .035, .0006), .0001, shadow_gold)

hinge_z, hinge_y = .463, .110


def pivot(name):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = .035
    model.objects.link(obj)
    obj.location = (0, hinge_y, hinge_z)
    return obj


seat_pivot = pivot("SeatPivot")
lid_pivot = pivot("LidPivot")


def attach(obj, parent):
    obj.parent = parent
    obj.matrix_parent_inverse = parent.matrix_world.inverted()
    # Explicit local coordinates keep exported hinge axes independent of evaluation timing.
    obj.location -= parent.location
    obj.matrix_parent_inverse.identity()


seat = surface("Seat Ring", [
    (.211,.291,.444),(.216,.296,.449),(.216,.296,.461),(.212,.292,.468),
    (.204,.284,.471),(.177,.248,.471),(.170,.240,.467),(.168,.238,.458),
    (.170,.240,.448),(.177,.248,.444)], center_y=-.13, mat=trim, subdiv=2)
# Mesh vertices are global coordinates, so translate the geometry into hinge-local space.
seat.parent = seat_pivot
for v in seat.data.vertices:
    v.co -= seat_pivot.location


def oval_lid(name, a, b, center_y, bottom, thickness, mat):
    n = 128
    v = []
    for z in (bottom, bottom + thickness):
        for j in range(n):
            t = 2*math.pi*j/n
            v.append((a*math.cos(t), min(center_y+b*math.sin(t), .134), z))
    f = [(j,(j+1)%n,n+(j+1)%n,n+j) for j in range(n)]
    f += [tuple(reversed(range(n))), tuple(n+j for j in range(n))]
    obj = mesh(name, v, f, mat)
    bevel(obj, .006, 5)
    obj.parent = lid_pivot
    for vertex in obj.data.vertices:
        vertex.co -= lid_pivot.location
    return obj


oval_lid("Solid Lid", .217, .299, -.13, .474, .021, gold)
oval_lid("Lid Inner Panel", .200, .278, -.13, .472, .006, trim)
for x in (-.155, .155):
    for y in (-.285, .035):
        bumper = cylinder("Lid Contact Pad", (x, y, .470), .010, .005, trim)
        attach(bumper, lid_pivot)
for x in (-.126, .126):
    box("Hinge Mount", (x, hinge_y, .447), (.054,.057,.015), .006, trim)
    cylinder("Hinge Barrel", (x,hinge_y,hinge_z), .018, .051, trim, along_x=True)
    cylinder("Hinge End Cap", (x+math.copysign(.028,x),hinge_y,hinge_z), .0125, .004, gold, along_x=True)
    cylinder("Hinge Washer", (x-.028,hinge_y,hinge_z), .018, .003, shadow_gold, along_x=True)
cylinder("Central Hinge Axle", (0,hinge_y,hinge_z), .011, .204, trim, along_x=True)

cylinder("Recessed Drain", (0,-.13,.285), .018, .004, shadow_gold)
lid_pivot.rotation_euler.x = -math.radians(98)
seat_pivot.rotation_euler.x = 0
bpy.context.view_layer.update()

# Bake all geometric modifiers for a portable, smooth GLB while preserving named parts.
for obj in list(model.objects):
    if obj.type == "MESH":
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)

assert "LidPivot" in bpy.data.objects and "SeatPivot" in bpy.data.objects
assert len(bowl.data.polygons) > 10000
assert all(math.isfinite(c) for o in model.objects if o.type == "MESH" for v in o.data.vertices for c in v.co)

# Product photography scene, excluded from the engine export.
floor_mat = material("Warm Grey Studio", (.25,.255,.26), metal=0, roughness=.68)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.002))
floor = bpy.context.object
floor.name = "Studio Floor"
floor.data.materials.append(floor_mat)
world = bpy.data.worlds.new("Studio Reflections")
bpy.context.scene.world = world
world.use_nodes = True
nodes = world.node_tree.nodes
background = next(n for n in nodes if n.type == "BACKGROUND")
background.inputs["Strength"].default_value = .65
env = nodes.new("ShaderNodeTexEnvironment")
studio = bpy.data.images.new("Bright Product Studio", width=512, height=256, float_buffer=True)
pixels = []
for row in range(256):
    elevation = row / 255
    for col in range(512):
        azimuth = col / 512 * 2 * math.pi
        value = 0.75 if elevation > 0.38 else 0.30
        for az in (0.1, 2.1, 4.6):
            angle = abs((azimuth - az + math.pi) % (2 * math.pi) - math.pi)
            if angle < 0.19 and 0.40 < elevation < 0.90:
                value = 2.0
        for az in (1.2, 3.6, 5.8):
            angle = abs((azimuth - az + math.pi) % (2 * math.pi) - math.pi)
            if angle < 0.10 and 0.35 < elevation < 0.84:
                value = 0.12
        pixels.extend((value, value, value, 1.0))
studio.pixels.foreach_set(pixels)
env.image = studio
world.node_tree.links.new(env.outputs["Color"], background.inputs["Color"])
env.image.pack()
# A bright studio with tall softboxes gives gold readable reflections from every angle.
bpy.context.scene.render.image_settings.file_format = "OPEN_EXR"
bpy.context.scene.render.image_settings.exr_codec = "ZIP"
bpy.context.scene.render.image_settings.color_depth = "16"
env.image.save_render(str(ASSETS / "studio.exr"), scene=bpy.context.scene)


def area(name, location, energy, size, target, size_y=None):
    data = bpy.data.lights.new(name,"AREA")
    data.energy = energy
    data.shape = "RECTANGLE"
    data.size = size
    data.size_y = size_y or size
    obj = bpy.data.objects.new(name,data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()


area("Tall Softbox Left",(-1.2,-.5,1.3),60, .5,(0,0,.45),1.8)
area("Tall Softbox Right",(1.0,.35,1.1),80,.45,(0,0,.45),1.5)
area("Front Fill",(.2,-1.4,1.5),45,1.3,(0,0,.5))
area("Top Rim",(0,.3,2.0),60,1.0,(0,0,.5))
camera_data = bpy.data.cameras.new("Product Camera")
camera = bpy.data.objects.new("Product Camera",camera_data)
bpy.context.scene.collection.objects.link(camera)
camera.location = (1.2,-1.6,1.1)
camera.rotation_euler = (Vector((0,-.015,.48))-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 1.22
bpy.context.scene.camera = camera
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_depth = "8"
scene.render.filepath = str(ROOT / "preview.png")

bpy.ops.object.select_all(action="DESELECT")
for obj in model.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = bowl
bpy.ops.export_scene.gltf(filepath=str(ASSETS/"golden_toilet.glb"), export_format="GLB",
                          use_selection=True, export_apply=True, export_animations=False)

for screen in bpy.data.screens:
    for ar in screen.areas:
        if ar.type == "VIEW_3D":
            ar.spaces.active.shading.type = "MATERIAL"
            ar.spaces.active.shading.studiolight_rotate_z = .5
            ar.spaces.active.region_3d.view_distance = 1.65
            ar.spaces.active.region_3d.view_location = (0,-.02,.46)
            ar.spaces.active.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
scene.unit_settings.system = "METRIC"
scene.unit_settings.length_unit = "METERS"
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "golden_toilet.blend"))
print("MODEL_SAVED: Blender source and hinged GLB", flush=True)
bpy.ops.render.render(write_still=True)
print("PREVIEW_SAVED", flush=True)
