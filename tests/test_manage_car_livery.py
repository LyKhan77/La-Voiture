import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
import shutil
import tempfile
import unittest
from tools.manage_car_livery import CarLiveryManager

class TestCarLiveryManager(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.car_slug = "test_car"
        self.textures_dir = os.path.join(self.test_dir, self.car_slug, "textures")
        os.makedirs(self.textures_dir, exist_ok=True)
        
        # Create dummy original base_color.png
        self.orig_file = os.path.join(self.textures_dir, "base_color.png")
        with open(self.orig_file, "w") as f:
            f.write("ORIGINAL_PIXELS")

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_backup_and_apply_and_restore(self):
        manager = CarLiveryManager(base_dir=self.test_dir)
        
        # Backup original
        backup_created = manager.backup_original(self.car_slug)
        self.assertTrue(backup_created)
        backup_path = os.path.join(self.textures_dir, "base_color_original.png")
        self.assertTrue(os.path.exists(backup_path))
        with open(backup_path, "r") as f:
            self.assertEqual(f.read(), "ORIGINAL_PIXELS")

        # Create a team livery file
        team_file = os.path.join(self.textures_dir, "base_color_team.png")
        with open(team_file, "w") as f:
            f.write("TEAM_LIVERY_PIXELS")

        # Apply team livery
        applied = manager.apply_team(self.car_slug)
        self.assertTrue(applied)
        with open(self.orig_file, "r") as f:
            self.assertEqual(f.read(), "TEAM_LIVERY_PIXELS")
        self.assertEqual(manager.get_status(self.car_slug), "team")

        # Restore original livery
        restored = manager.restore_original(self.car_slug)
        self.assertTrue(restored)
        with open(self.orig_file, "r") as f:
            self.assertEqual(f.read(), "ORIGINAL_PIXELS")
        self.assertEqual(manager.get_status(self.car_slug), "original")

if __name__ == "__main__":
    unittest.main()
