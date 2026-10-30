"""Actual accepted ground archive readers under foreign cwd/Git, with no native or Game launch."""
import json
import unittest

from tools.qa.ground import axial_road_verify as axial
from tools.qa.ground import decoration_verify as decoration
from tools.qa.ground import garden_verify as garden
from tools.qa.ground import ground_edge_verify as edge
from tools.qa.ground import ground_layers as layers
from tools.qa.ground import ground_seasons_verify as seasons
from tools.qa.ground import meadow_verify as meadow
from tools.qa.ground import plaza_verify as plaza
from tools.qa.ground import road_network_verify as roads
from tools.qa.ground import terrain_revision_verify as revision
from tools.qa.world import test_world_context as fixtures


class GroundContextTests(unittest.TestCase):
    """Do not replace Git, archived source bytes or artifact/index checks."""
    git = fixtures.WorldContextTests.git
    repository = fixtures.WorldContextTests.repository
    foreign_context = fixtures.WorldContextTests.foreign_context

    def check_reader(self, module):
        """Return the exact accepted source envelope using the reader's own Git repository."""
        folder = module.REPORT / 'native'
        original = (folder / 'source.json').read_bytes()
        with self.foreign_context():
            result = module.provenance(folder)
        self.assertEqual(result, json.loads(original))
        self.assertEqual((folder / 'source.json').read_bytes(), original)

    def test_axial_road_archive_under_foreign_git(self):
        """Axial road's real source, artifact and index validation ignores caller overrides."""
        self.check_reader(axial)

    def test_decoration_archive_under_foreign_git(self):
        """Decoration source coverage and frozen native artifacts stay bound to their own base."""
        self.check_reader(decoration)

    def test_garden_archive_under_foreign_git(self):
        """Garden's accepted inputs are never looked up in the caller's foreign repository."""
        self.check_reader(garden)

    def test_ground_edge_archive_under_foreign_git(self):
        """Ground edge keeps exact historical blobs and the tracked proof requirement."""
        self.check_reader(edge)

    def test_ground_layers_archive_under_foreign_git(self):
        """Already cleaned ground-layers Git operations remain a positive control."""
        self.check_reader(layers)

    def test_seasons_archive_under_foreign_git(self):
        """Seasonal source envelopes and their full artifacts survive foreign Git config/index."""
        self.check_reader(seasons)

    def test_meadow_archive_under_foreign_git(self):
        """Meadow's real archive validation reads the pinned source in this checkout."""
        self.check_reader(meadow)

    def test_plaza_archive_under_foreign_git(self):
        """Plaza's exact sources and tracked artifacts are independent of caller cwd."""
        self.check_reader(plaza)

    def test_roads_archive_under_foreign_git(self):
        """Road network's immutable source/index checks reject inherited repository selection."""
        self.check_reader(roads)

    def test_revision_archive_under_foreign_git(self):
        """Terrain revision keeps its actual historical envelope and complete tracked proof."""
        self.check_reader(revision)


if __name__ == '__main__':
    unittest.main()
