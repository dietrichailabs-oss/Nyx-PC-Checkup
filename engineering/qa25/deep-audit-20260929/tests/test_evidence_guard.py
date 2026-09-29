"""These tests validate the evidence guard, NOT the Nyx Windows application."""
import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('guard', Path(__file__).parents[1]/'tools'/'qa25_evidence_guard.py')
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)

class EvidenceGuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.root = Path(self.tmp.name)
        self.geo = dict(coordinate_space='physical-screen-pixels', focused=True, layout_settled=True,
                        full_cell_rect=[10,10,300,64], clip_rectangles=[[0,0,800,400]],
                        scale_percent=200, policy_minimum_logical=150, column_width_px=300,
                        column_minimum_px=300, essential_text_width_px=120, horizontal_padding_px=8)
    def tearDown(self): self.tmp.cleanup()
    def test_rounding_matches_frozen_half_pixel_policy(self):
        self.geo.update(scale_percent=125,policy_minimum_logical=130,
                        full_cell_rect=[10,10,162,64],column_width_px=162,column_minimum_px=162)
        self.assertTrue(g.evaluate_geometry(self.geo)['passed'])
    def test_geometry_root_type(self):
        with self.assertRaises(ValueError): g.evaluate_geometry([])
    def test_matrix_root_type(self):
        self.assertFalse(g.validate_matrix([],self.root)['valid'])
    def test_geometry_happy(self): self.assertTrue(g.evaluate_geometry(self.geo)['passed'])
    def test_one_pixel_sliver_rejected(self):
        self.geo['clip_rectangles']=[[10,0,1,400]]
        old_width, old_height = 1,64
        self.assertTrue(old_width>0 and old_height>=64) # legacy horizontal condition
        self.assertFalse(g.evaluate_geometry(self.geo)['passed'])
    def test_collapsed_column_rejected_even_fully_visible(self):
        self.geo.update(full_cell_rect=[10,10,20,64],column_width_px=20,column_minimum_px=10)
        self.assertFalse(g.evaluate_geometry(self.geo)['passed'])
    def test_text_overflow_rejected(self):
        self.geo['essential_text_width_px']=400
        self.assertFalse(g.evaluate_geometry(self.geo)['passed'])
    def test_clipping_ancestor_rejected(self):
        self.geo['clip_rectangles'].append([0,0,100,400])
        self.assertFalse(g.evaluate_geometry(self.geo)['passed'])
    def test_offscreen_rejected(self):
        self.geo['clip_rectangles']=[[900,900,100,100]]
        self.assertFalse(g.evaluate_geometry(self.geo)['passed'])
    def test_focus_required(self):
        self.geo['focused']=False
        with self.assertRaises(ValueError): g.evaluate_geometry(self.geo)
    def test_unsettled_rejected(self):
        self.geo['layout_settled']=False
        with self.assertRaises(ValueError): g.evaluate_geometry(self.geo)
    def test_coordinate_basis_required(self):
        self.geo['coordinate_space']='logical'
        with self.assertRaises(ValueError): g.evaluate_geometry(self.geo)
    def test_non_finite_rejected(self):
        self.geo['column_width_px']=float('nan')
        with self.assertRaises(ValueError): g.evaluate_geometry(self.geo)
    def test_boolean_dimension_rejected(self):
        self.geo['column_width_px']=True
        with self.assertRaises(ValueError): g.evaluate_geometry(self.geo)
    def test_zero_rectangle_rejected(self):
        self.geo['full_cell_rect']=[0,0,0,64]
        with self.assertRaises(ValueError): g.evaluate_geometry(self.geo)
    def test_unknown_not_blank_text_requirement(self):
        self.geo['essential_text_width_px']=0
        with self.assertRaises(ValueError): g.evaluate_geometry(self.geo)
    def test_template_is_132_unexecuted(self):
        r=g.validate_matrix(g.make_matrix(),self.root)
        self.assertTrue(r['valid']);self.assertFalse(r['complete']);self.assertEqual(r['counts'],{'NOT_RUN':132})
    def test_missing_cell(self):
        d=g.make_matrix();d['cells'].pop()
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_duplicate_cell(self):
        d=g.make_matrix();d['cells'][-1]=copy.deepcopy(d['cells'][0])
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_wrong_candidate(self):
        d=g.make_matrix();d['candidate']['source_commit']='0'*40
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_invented_pass_without_evidence(self):
        d=g.make_matrix();d['cells'][0]['verdict']='PASS'
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_unsupported_verdict(self):
        d=g.make_matrix();d['cells'][0]['verdict']='ASSUMED_PASS'
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_relative_file_and_hash(self):
        (self.root/'a.txt').write_text('abc',encoding='utf8')
        self.assertEqual(g.safe_file(self.root,'a.txt'),self.root/'a.txt')
        self.assertEqual(g.digest(self.root/'a.txt'),'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD')
    def test_traversal_rejected(self):
        with self.assertRaises(ValueError): g.safe_file(self.root,'../a.txt')
    def test_windows_absolute_rejected(self):
        with self.assertRaises(ValueError): g.safe_file(self.root,'C:\\a.txt')
    def test_symlink_rejected(self):
        (self.root/'a').write_text('x');(self.root/'b').symlink_to(self.root/'a')
        with self.assertRaises(ValueError): g.safe_file(self.root,'b')
    def test_duplicate_json_rejected(self):
        p=self.root/'x.json';p.write_text('{"x":1,"x":2}')
        with self.assertRaises(ValueError): g.load_json(p)
    def test_missing_candidate_archives_fail(self): self.assertEqual(len(g.verify_artifacts(self.root)),3)

    def pass_cell_fixture(self, scale=100, theme='FollowWindows'):
        # Fictional records exercise validation logic only. Never exported as native evidence.
        d=g.make_matrix()
        c=next(c for c in d['cells'] if c['scale_percent']==scale and c['theme']==theme)
        c['verdict']='PASS';c['checks']=dict.fromkeys(g.CHECKS,True)
        c['session']={
            'source_commit':g.CANDIDATE['source_commit'],'build':g.CANDIDATE['build'],
            'powershell_version':'5.1.0.0','measurement_mode':'installed_native',
            'session_id':'UNIT-TEST-ONLY','os_build':'unit-fixture','dpi_method':'unit-fixture',
            'observer_awareness':'PerMonitorV2','capture_basis':'unit-fixture',
            'effective_dpi':scale*.96,'selected_theme':theme,'resolved_theme':'Light' if theme=='FollowWindows' else theme,
            'resolution':[1366,768]}
        for kind in ('screenshot','native_record','installed_identity'):
            name=kind+'.test.txt';path=self.root/name
            path.write_text('FICTIONAL EVIDENCE FOR UNIT TEST ONLY',encoding='utf8')
            c['evidence'].append({'path':name,'sha256':g.digest(path),'kind':kind})
        return d,c
    def test_well_formed_pass_record_is_valid_not_complete(self):
        d,c=self.pass_cell_fixture();r=g.validate_matrix(d,self.root)
        self.assertTrue(r['valid']);self.assertFalse(r['complete']);self.assertEqual(r['counts']['PASS'],1)
    def test_unhashable_verdict_rejected(self):
        d=g.make_matrix();d['cells'][0]['verdict']=[]
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_string_true_check_rejected(self):
        d,c=self.pass_cell_fixture();c['checks']['keyboard_operable']='true'
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_pass_with_tampered_file_rejected(self):
        d,c=self.pass_cell_fixture();(self.root/c['evidence'][0]['path']).write_text('changed')
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_pass_wrong_native_candidate_rejected(self):
        d,c=self.pass_cell_fixture();c['session']['source_commit']='f'*40
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_ps7_session_rejected(self):
        d,c=self.pass_cell_fixture();c['session']['powershell_version']='7.4.0'
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_integration_not_native_matrix_rejected(self):
        d,c=self.pass_cell_fixture();c['session']['measurement_mode']='installed_integration'
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_dpi_unaware_observer_rejected(self):
        d,c=self.pass_cell_fixture();c['session']['observer_awareness']='DPI-unaware'
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_wrong_measured_dpi_rejected(self):
        d,c=self.pass_cell_fixture(scale=200);c['session']['effective_dpi']=96
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_explicit_theme_mismatch_rejected(self):
        d,c=self.pass_cell_fixture(theme='Dark');c['session']['resolved_theme']='Light'
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_constrained_resolution_missing_rejected(self):
        d,c=self.pass_cell_fixture(scale=200);c['session']['resolution']=[1920,1080]
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_missing_screenshot_kind_rejected(self):
        d,c=self.pass_cell_fixture();c['evidence']=c['evidence'][1:]
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_boolean_resolution_rejected(self):
        d,c=self.pass_cell_fixture();c['session']['resolution']=[True,768]
        self.assertFalse(g.validate_matrix(d,self.root)['valid'])
    def test_incomplete_cell_height_rejected(self):
        self.geo['clip_rectangles']=[[0,0,800,30]]
        self.assertFalse(g.evaluate_geometry(self.geo)['passed'])
    def test_negative_padding_rejected(self):
        self.geo['horizontal_padding_px']=-1
        with self.assertRaises(ValueError):g.evaluate_geometry(self.geo)

if __name__=='__main__': unittest.main(verbosity=2)
