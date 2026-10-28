#!/usr/bin/env python3
"""Protocol mutation tests use synthetic inputs; native acceptance remains a separate gate."""
import copy
import json
import math
import shutil
from pathlib import Path
import tempfile
import unittest
from tools.qa.performance import perf_contract as p


def fixture():
    """Creates a deliberately synthetic 30.6s trace to exercise the validator, not claim native performance."""
    state={'window':[1152,648],'root':[1152,648],'readback':[1152,648],'visible':[1152,648],
        'focused':True,'mode':0,'camera':[120.25,430.25]}
    data={'schema':1,'task':'VPERF-001','fault':'','display_server':'macOS','driver':'opengl3','errors':[],
        'seconds':30,'vsync':1,'physics_hz':60,'max_fps':0,'zoom':1.2,'hud_zoom':1,'field':[960,540],
        'warmup_frames':120,'readback_during_samples':False,'manual_simulation':False,'disk_io_during_samples':False,
        'observer_buffer_bytes':15840000,'gpu_time_ms':None,'gpu_time_status':'unavailable',
        'profile':'Codex-VPERF-001-synthetic','reduced_motion':True,'audio_enabled':False,
        'initial':copy.deepcopy(state),'final':copy.deepcopy(state),'samples':900}
    values=[]
    for i in range(900):
        row=dict.fromkeys(p.FIELDS,0.0)
        row.update(usec=(i+1)*34000,interval_ms=34,engine_frame_ms=2,engine_physics_ms=5,callback_span_ms=.1,
            draw_calls=140,static_bytes=140000000,texture_bytes=680000000,process_frame=i+120,physics_frame=i*2+240,
            absolute_minutes=720+i*.034,camera_x=120.25,camera_y=430.25,focused=1,window_x=1152,window_y=648)
        values.append(row)
    return data,values


def comparable_summary(summary):
    """Сравнивает суммы длительностей до наносекунды; остальные поля и архивы остаются точными."""
    result = copy.deepcopy(summary)
    # Python 3.12 изменил sum(float). Не округляем p95, память, флаги или исходные отсчёты.
    for name in ["repeat-1", "repeat-2", "repeat-3", "long-cycle"]:
        run = result["runs"][name]
        for section in [run, run["render"]]:
            seconds = section["seconds"]
            if type(seconds) is not float or not math.isfinite(seconds):
                raise ValueError("finite float duration required")
            section["seconds"] = round(seconds, 9)
    return result


class PerfContractTests(unittest.TestCase):
    """Rejects contaminated or re-labelled measurements without running Godot during tests."""
    def setUp(self):
        """Every mutation gets fresh synthetic objects."""
        self.data,self.values=fixture()

    def reject(self,text):
        """Requires the specific contract failure, not any unrelated exception."""
        with self.assertRaisesRegex(ValueError,text): p.validate_run(self.data,self.values,30)

    def test_complete_protocol_input(self):
        """Complete synthetic input exercises positive validation, without constituting native evidence."""
        self.assertEqual(p.validate_run(self.data,self.values,30)['interval_ms']['p95'],34)

    def test_headless_rejected(self):
        """Headless timings cannot enter native comparison."""
        self.data['display_server']='headless'; self.reject('native driver')

    def test_host_framebuffer_mismatch(self):
        """A correct logical canvas does not excuse a smaller physical host."""
        self.data['initial']['window']=[960,540]; self.reject('host/framebuffer')

    def test_actual_readback_required(self):
        """Window size alone does not prove the framebuffer dimensions."""
        self.data['final']['readback']=[2304,1296]; self.reject('host/framebuffer')

    def test_mid_sample_focus_loss(self):
        """A single lost-focus observation invalidates the session."""
        self.values[500]['focused']=0; self.reject('per-frame native')

    def test_mid_sample_pause(self):
        """Paused fast frames cannot make the world look cheaper."""
        self.values[500]['modal']=1; self.reject('per-frame native')

    def test_moving_comparison_camera(self):
        """Different composition is rejected even with a matching start frame."""
        self.values[500]['camera_x']+=24; self.reject('per-frame camera')

    def test_no_gpu_inference(self):
        """CPU or interval values cannot be relabelled GPU time."""
        self.data['gpu_time_ms']=3; self.reject('GPU time unavailable')

    def test_manual_simulation_rejected(self):
        """Fixed-clock diagnostic captures are excluded."""
        self.data['manual_simulation']=True; self.reject('contaminated')

    def test_vsync_changed(self):
        """Comparison cannot mix display pacing settings."""
        self.data['vsync']=0; self.reject('VSync')

    def test_truncation(self):
        """A shorter trace cannot keep the original declared duration."""
        self.values=self.values[:400]; self.data['samples']=400; self.reject('duration')

    def test_nan(self):
        """Non-finite observations are not dropped from quantiles."""
        self.values[12]['interval_ms']=float('nan'); self.reject('non-finite')

    def test_clock_tampering(self):
        """Raw monotonic deltas must reconstruct the recorded intervals."""
        self.values[12]['usec']+=1000; self.reject('clock interval')

    def test_static_world(self):
        """A visible idle image must still contain real world simulation."""
        for row in self.values: row['absolute_minutes']=720
        self.reject('world is not live')

    def test_hitch_preserved(self):
        """An extreme frame remains in max and duration instead of being trimmed."""
        for i,row in enumerate(self.values):
            if i==500: row['interval_ms']=1000
            if i>=500: row['usec']+=966000
        self.assertEqual(p.validate_run(self.data,self.values,30)['interval_ms']['max'],1000)

    def test_cpu_time_meaning(self):
        """OS cumulative CPU seconds support both time formats, and are distinct from RSS."""
        self.assertEqual(p.cpu_seconds('01:02.50'),62.5)
        self.assertEqual(p.cpu_seconds('01:02:03.50'),3723.5)

    def external_fixture(self):
        """Creates synthetic OS samples with a separate CPU clock and KiB RSS."""
        data={'pid':123,'started_utc':0,'ended_utc':31}
        env={'rss_cpu_samples':[{'utc':i*5+1,'raw':f'123 1000 00:0{i+1}.00 20.0','pid':123,'other_godot_pids':[]} for i in range(6)]}
        return env,data

    def test_external_cpu_and_rss_separate(self):
        """CPU delta uses wall time; RSS is independently converted from KiB."""
        metric=p.process_samples(*self.external_fixture())
        self.assertEqual(metric['rss_first'],1024000)
        self.assertEqual(metric['cpu_percent_of_one_core'],20)

    def test_external_missing(self):
        """Absent process-memory evidence cannot become a zero-memory claim."""
        env,data=self.external_fixture(); env['rss_cpu_samples']=[]
        with self.assertRaisesRegex(ValueError,'missing'): p.process_samples(env,data)

    def test_external_wrong_pid(self):
        """Another process's RSS cannot satisfy this session's evidence."""
        env,data=self.external_fixture(); env['rss_cpu_samples'][2]['pid']=456
        with self.assertRaisesRegex(ValueError,'process mismatch'): p.process_samples(env,data)

    def test_competing_godot(self):
        """A competing engine invalidates admission without being terminated."""
        env,data=self.external_fixture(); env['rss_cpu_samples'][2]['other_godot_pids']=['456']
        with self.assertRaisesRegex(ValueError,'competing Godot'): p.process_samples(env,data)

    def test_external_nan(self):
        """NaN timestamps are rejected rather than silently filtered out."""
        env,data=self.external_fixture(); env['rss_cpu_samples'][2]['utc']=float('nan')
        with self.assertRaisesRegex(ValueError,'timestamp'): p.process_samples(env,data)

    def test_unfinished_packet(self):
        """A recoverable partial collection is never a completed protocol."""
        with tempfile.TemporaryDirectory(prefix='vperf-incomplete-') as name:
            folder=Path(name); (folder/'source.json').write_text(json.dumps({'task':'VPERF-001','complete':False,'schedule':p.SCHEDULE}))
            with self.assertRaisesRegex(ValueError,'incomplete'): p.provenance(folder,p.SCHEDULE)

    def environment_fixture(self):
        """Builds synthetic hardware and power records to test comparison admission."""
        device={'system':'Darwin','os_version':'test','architecture':'x86_64','machine':{'hw.model':'fixture'},'adapter':'fixture GPU','engine':'fixture engine'}
        ctx={'hardware':{k:device[k] for k in ['system','os_version','architecture','machine']},
            'power':"Now drawing from 'AC Power'",'power_settings':'AC Power:\n lowpowermode 0\n gpuswitch 2\n',
            'thermal':'CPU_Scheduler_Limit = 100\nCPU_Speed_Limit = 100'}
        env={'before':copy.deepcopy(ctx),'after':copy.deepcopy(ctx),'rss_cpu_samples':[{'power_source':ctx['power']}]}
        return env,{'adapter':device['adapter'],'engine':device['engine']},device

    def test_matching_environment(self):
        """Matching machine and stable observed AC power are admitted as their own profile."""
        self.assertEqual(p.validate_environment(*self.environment_fixture()),"Now drawing from 'AC Power'")

    def test_power_switch_in_middle(self):
        """Stable boundaries cannot hide an observed battery interval in an AC session."""
        env,data,device=self.environment_fixture(); env['rss_cpu_samples'][0]['power_source']="Now drawing from 'Battery Power'"
        with self.assertRaisesRegex(ValueError,'power changed'): p.validate_environment(env,data,device)

    def test_wrong_active_power_settings(self):
        """The active section must match; unrelated battery settings cannot excuse low power AC."""
        env,data,device=self.environment_fixture(); env['after']['power_settings']='AC Power:\n lowpowermode 1\n gpuswitch 2\nBattery Power:\n lowpowermode 0\n gpuswitch 2\n'
        with self.assertRaisesRegex(ValueError,'active power'): p.validate_environment(env,data,device)

    def test_different_reference_machine(self):
        """A matching adapter name alone does not approve another CPU/host."""
        env,data,device=self.environment_fixture(); env['after']['hardware']['architecture']='arm64'
        with self.assertRaisesRegex(ValueError,'reference machine'): p.validate_environment(env,data,device)

    def test_thermal_limit(self):
        """An explicit boundary CPU limit cannot disappear from comparison admission."""
        env,data,device=self.environment_fixture(); env['after']['thermal']='CPU_Scheduler_Limit = 80\nCPU_Speed_Limit = 100'
        with self.assertRaisesRegex(ValueError,'throttling'): p.validate_environment(env,data,device)

    def render_fixture(self):
        """Creates synthetic post-draw records, independently of the idle trace."""
        return {'render_samples':900,'render_boundary':'RenderingServer.frame_post_draw; fixture'},[
            {'usec':(i+1)*34000,'interval_ms':34,'render_frame':i+100,'process_frame':i*2+120} for i in range(900)]

    def test_render_boundaries_separate(self):
        """Rendering counters can advance once while idle advances twice; their rates are not conflated."""
        self.assertEqual(p.validate_render(*self.render_fixture(),30)['frames'],900)

    def test_render_clock_tampering(self):
        """A re-labelled interval cannot disagree with monotonic post-draw timestamps."""
        data,values=self.render_fixture(); values[20]['interval_ms']=1
        with self.assertRaisesRegex(ValueError,'render clock'): p.validate_render(data,values,30)

    def test_duplicate_render_counter(self):
        """Repeated idle observations cannot masquerade as distinct rendered frames."""
        data,values=self.render_fixture(); values[20]['render_frame']=values[19]['render_frame']
        with self.assertRaisesRegex(ValueError,'render frame order'): p.validate_render(data,values,30)

    def test_no_render_trace(self):
        """A complete idle trace alone does not establish rendering intervals."""
        data,_=self.render_fixture()
        with self.assertRaisesRegex(ValueError,'sample count'): p.validate_render(data,[],30)

    def test_render_not_gpu_timer(self):
        """A claimed GPU/presentation timer must not replace the declared submission boundary."""
        data,values=self.render_fixture(); data['render_boundary']='GPU completion'
        with self.assertRaisesRegex(ValueError,'render boundary'): p.validate_render(data,values,30)

    def test_signed_partial_audit_cannot_complete_task(self):
        """Actual focus-loss evidence remains rejected after read-only audit; the packet is never re-signed."""
        folder=p.REPORT/'revisions/render-focus-v4'; before=p.sha(folder/'source.json')
        result=p.audit(folder)
        self.assertEqual(result['counts'],{'valid':3,'rejected':1,'missing':0})
        self.assertFalse(result['acceptance_granted'])
        self.assertEqual(before,p.sha(folder/'source.json'))
        with self.assertRaisesRegex(ValueError,'incomplete'): p.verify(folder)

    def test_native_summary_reproducible(self):
        """The complete raw package reproduces the stored result without closing FPS or leak gates."""
        result=p.verify(p.REPORT/'native')
        self.assertEqual(
            comparable_summary(result),
            comparable_summary(p.read(p.REPORT / 'summary.json')),
        )
        self.assertTrue(result['contract_accepted'])
        self.assertFalse(result['release_fps_accepted'])
        self.assertFalse(result['leak_plateau_accepted'])
        self.assertIsNone(result['gpu_time_ms'])

    def test_actual_native_controls(self):
        """Real window resize and modal pause evidence must still be denied on a clean checkout."""
        result=p.verify_controls(p.REPORT/'controls')
        self.assertIn('host/framebuffer',result['resize'])
        self.assertIn('modal',result['pause'])

    def test_changed_raw_artifact(self):
        """Editing a compressed trace cannot preserve acceptance through the old artifact signature."""
        with tempfile.TemporaryDirectory(prefix='vperf-corrupt-') as name:
            folder=Path(name)/'native'; shutil.copytree(p.REPORT/'native',folder)
            with (folder/'repeat-1/rows.csv.gz').open('ab') as stream: stream.write(b'changed')
            with self.assertRaisesRegex(ValueError,'artifact hash changed'): p.verify(folder)

    def test_missing_raw_artifact(self):
        """Missing render observations cannot silently fall back to the idle-only prototype."""
        with tempfile.TemporaryDirectory(prefix='vperf-missing-') as name:
            folder=Path(name)/'native'; shutil.copytree(p.REPORT/'native',folder)
            (folder/'repeat-1/render-rows.csv.gz').unlink()
            with self.assertRaisesRegex(ValueError,'artifact coverage'): p.verify(folder)


class SummaryPrecisionTests(unittest.TestCase):
    """Отличает шум суммирования от изменения измерений, структуры и решения приёмки."""

    def setUp(self):
        self.stored = p.read(p.REPORT / "summary.json")
        self.changed = copy.deepcopy(self.stored)

    def test_subnanosecond_sum_difference(self):
        self.changed["runs"]["long-cycle"]["render"]["seconds"] += 4e-12
        self.assertEqual(comparable_summary(self.changed), comparable_summary(self.stored))
        self.assertNotEqual(self.changed, self.stored)

    def test_nanosecond_duration_change_is_rejected(self):
        self.changed["runs"]["long-cycle"]["render"]["seconds"] += 1e-9
        self.assertNotEqual(comparable_summary(self.changed), comparable_summary(self.stored))

    def test_microsecond_duration_change_is_rejected(self):
        self.changed["runs"]["long-cycle"]["render"]["seconds"] += 1e-6
        self.assertNotEqual(comparable_summary(self.changed), comparable_summary(self.stored))

    def test_quantile_stays_exact(self):
        self.changed["runs"]["repeat-1"]["interval_ms"]["p95"] += 1e-12
        self.assertNotEqual(comparable_summary(self.changed), comparable_summary(self.stored))

    def test_memory_stays_exact(self):
        self.changed["runs"]["repeat-1"]["static_bytes"]["first"] += 1
        self.assertNotEqual(comparable_summary(self.changed), comparable_summary(self.stored))

    def test_acceptance_stays_exact(self):
        self.changed["release_fps_accepted"] = True
        self.assertNotEqual(comparable_summary(self.changed), comparable_summary(self.stored))

    def test_missing_section_is_rejected(self):
        del self.changed["runs"]["repeat-1"]["render"]
        with self.assertRaises(KeyError):
            comparable_summary(self.changed)

    def test_nonfinite_duration_is_rejected(self):
        self.changed["runs"]["repeat-1"]["seconds"] = float("nan")
        with self.assertRaisesRegex(ValueError, "finite float"):
            comparable_summary(self.changed)


if __name__=='__main__': unittest.main()
