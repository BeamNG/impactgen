
from beamngpy.api.beamng import Api


class ImpactGenAPI(Api):
    def set_image_properties(self, image_width, image_height, color_format, annot_format, camera_radius, camera_height, fov):
        req = dict(type='ImpactGenSetImageProperties')
        req['imageWidth'] = image_width
        req['imageHeight'] = image_height
        req['colorFmt'] = color_format
        req['annotFmt'] = annot_format
        req['radius'] = camera_radius
        req['height'] = camera_height
        req['fov'] = fov

        self._send(req).ack('ImpactGenImagePropertiesSet')

    def set_post_settings(self, vid, settings):
        req = dict(type='ImpactGenPostSettings')
        req['ego'] = vid
        req['time'] = settings[0]
        req['clouds'] = settings[1]
        req['fog'] = settings[2]
        req['color'] = settings[3]
        if len(settings) > 4:
            req['skybox'] = settings[4]
        if len(settings) > 5:
            req['ground'] = settings[5]
        self._send(req).ack('ImpactGenPostSet')

    def produce_output(self):
        req = dict(type='ImpactGenGenerateOutput')
        request = self._send(req)

        files = {}

        while True:
            response = request.recv()
            if response['type'] == 'ImpactGenOutputEnd':
                files['mesh.gltf'] = response['mesh']
                files['scenario.json'] = response['scenario']
                files['parts.json'] = response['parts']
                break
            elif response['type'] == 'ImpactGenOutput':
                del response['type']
                for filename, value in response.items():
                    files[filename] = value
            else:
                raise Exception('unexpected')
        return files

    def run_t_bone_crash(self, ego_vid, other_vid, config, pos_a, angle, pos_b, rot_b, throttle):
        req = dict(type='ImpactGenRunTBone')
        req['ego'] = ego_vid
        req['other'] = other_vid
        req['config'] = config
        req['aPosition'] = pos_a
        req['angle'] = angle
        req['bPosition'] = pos_b
        req['bRotation'] = rot_b
        req['throttle'] = throttle\

        self._send(req).ack('ImpactGenTBoneRan')

    def run_linear_crash(self, ego_vid, other_vid, config, pos_a, angle, pos_b, rot_b, throttle):
        req = dict(type='ImpactGenRunLinear')
        req['ego'] = ego_vid
        req['other'] = other_vid
        req['config'] = config
        req['aPosition'] = pos_a
        req['angle'] = angle
        req['bPosition'] = pos_b
        req['bRotation'] = rot_b
        req['throttle'] = throttle

        self._send(req).ack('ImpactGenLinearRan')

    def run_pole_crash(self, ego_vid, config, pos, angle, throttle, pole):
        req = dict(type='ImpactGenRunPole')
        req['ego'] = ego_vid
        req['config'] = config
        req['position'] = pos
        req['angle'] = angle
        req['throttle'] = throttle
        if pole is not None:
            req['polePosition'] = pole
        self._send(req).ack('ImpactGenPoleRan')

    def run_no_crash(self, ego_vid, config):
        req = dict(type='ImpactGenRunNonCrash')
        req['ego'] = ego_vid
        req['config'] = config
        self._send(req).ack('ImpactGenNonCrashRan')
