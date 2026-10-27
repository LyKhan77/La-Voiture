import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
import tempfile
import unittest
import numpy as np
from PIL import Image
from tools.recolor_car_texture import recolor_hue_range

class TestRecolorCarTexture(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.src_path = os.path.join(self.test_dir, "sample.png")
        self.out_path = os.path.join(self.test_dir, "recolored.png")

        # Create a 30x10 synthetic test image:
        # Columns 0..9: Bright Pure Green (0, 255, 0)
        # Columns 10..19: Neutral Dark Carbon (30, 30, 30)
        # Columns 20..29: Neutral White (240, 240, 240)
        arr = np.zeros((10, 30, 3), dtype=np.uint8)
        arr[:, 0:10] = [0, 255, 0]      # Green
        arr[:, 10:20] = [30, 30, 30]    # Carbon / dark
        arr[:, 20:30] = [240, 240, 240] # White
        Image.fromarray(arr).save(self.src_path)

    def tearDown(self):
        import shutil
        shutil.rmtree(self.test_dir)

    def test_recolor_preserves_neutrals(self):
        # Recolor green (120 deg) to Magenta #D946EF
        recolor_hue_range(
            img_path=self.src_path,
            out_path=self.out_path,
            src_hue_deg=120.0,
            hue_tolerance=30.0,
            target_hex="D946EF"
        )
        self.assertTrue(os.path.exists(self.out_path))

        out_img = Image.open(self.out_path).convert("RGB")
        out_arr = np.array(out_img)

        # Check Green region (was 0, 255, 0 -> should now be magenta-ish, R > 150, B > 150)
        green_region = out_arr[:, 5]
        mean_r = np.mean(green_region[:, 0])
        mean_g = np.mean(green_region[:, 1])
        mean_b = np.mean(green_region[:, 2])
        self.assertGreater(mean_r, 150, "Red channel in recolored patch should be high")
        self.assertGreater(mean_b, 150, "Blue channel in recolored patch should be high")
        self.assertLess(mean_g, mean_r, "Green channel in recolored patch should be lower than red")

        # Check Carbon region (was 30, 30, 30 -> should stay neutral within 5 delta)
        carbon_region = out_arr[:, 15]
        self.assertAlmostEqual(np.mean(carbon_region[:, 0]), 30, delta=5)
        self.assertAlmostEqual(np.mean(carbon_region[:, 1]), 30, delta=5)
        self.assertAlmostEqual(np.mean(carbon_region[:, 2]), 30, delta=5)

        # Check White region (was 240, 240, 240 -> should stay neutral white within 5 delta)
        white_region = out_arr[:, 25]
        self.assertAlmostEqual(np.mean(white_region[:, 0]), 240, delta=5)
        self.assertAlmostEqual(np.mean(white_region[:, 1]), 240, delta=5)
        self.assertAlmostEqual(np.mean(white_region[:, 2]), 240, delta=5)

if __name__ == "__main__":
    unittest.main()
