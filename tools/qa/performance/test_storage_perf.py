"""Не допускает ложной приёмки короткой, неполной, фоновой или зависшей трассы хранилища."""
import unittest
from tools.qa.performance.analyze_storage_perf import inspect


class StoragePerfTest(unittest.TestCase):
    def report(self):
        return dict(status="COMPLETE",gpu="fixture native GPU",instrumented=False,window=[3584,2240],cases=[dict(
            case="cabinet",variant="full",repeat=0,frames=3,intervals_ms=[16,16,16],simulation_minutes=0,
            focus_draws=dict(focused=4,unfocused=0),windows={"(3584, 2240)":4},
            location="cottage_interior",actual_location="cottage_interior",first_present_ms=30)])

    def test_qualified_frames_and_short_diagnostic_are_distinct(self):
        self.assertEqual(inspect(self.report(),minimum=3)[0]["admission"],"QUALIFIED_RUN")
        self.assertIn("short_run",inspect(self.report())[0]["reasons"])

    def test_context_errors_never_qualify(self):
        for key,value,reason in [("pause_on_focus_loss",True,"focus_pause_not_disabled"),("status","TIMEOUT","incomplete_report"),("gpu","","native_gpu_not_recorded"),("instrumented",True,"instrumentation_present")]:
            with self.subTest(key=key):
                report=self.report(); report[key]=value
                self.assertIn(reason,inspect(report,minimum=3)[0]["reasons"])

    def test_pause_focus_window_and_count_must_be_proven(self):
        for key,value,reason in [("simulation_minutes",1,"world_not_paused"),("focus_draws",{},"focus_not_stable"),
             ("windows",{"(1152, 648)":4},"window_not_stable"),("frames",4,"frame_count_mismatch"),
             ("actual_location","overworld","location_changed")]:
            with self.subTest(key=key):
                report=self.report(); report["cases"][0][key]=value
                self.assertIn(reason,inspect(report,minimum=3)[0]["reasons"])

    def test_single_stall_is_not_hidden_by_good_average(self):
        report=self.report(); case=report["cases"][0]
        case.update(intervals_ms=[16]*1000+[110],frames=1001,focus_draws=dict(focused=1002,unfocused=0))
        result=inspect(report,minimum=3)[0]
        self.assertEqual(result["budget"],"FAIL")
        self.assertIn("stall_over100",result["violations"])

    def test_no_samples_is_invalid(self):
        report=self.report(); report["cases"][0]["intervals_ms"]=[]
        self.assertEqual(inspect(report)[0]["admission"],"INVALID")


if __name__=="__main__":
    unittest.main()
