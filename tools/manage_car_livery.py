#!/usr/bin/env python3
import argparse
import filecmp
import os
import shutil
import sys

ALL_CARS = [
    "mercedes_amg", "audi_r8", "nissan_gtr", "bmw_m4", "aston_vantage",
    "chevy_corvette", "honda_nsx", "lexus_rcf", "mclaren_720s", "lambo_huracan",
    "ferrari_296", "ford_mustang", "toyota_supra"
]

class CarLiveryManager:
    def __init__(self, base_dir="assets/cars"):
        self.base_dir = os.path.abspath(base_dir)

    def _get_texture_paths(self, car_slug: str):
        car_tex_dir = os.path.join(self.base_dir, car_slug, "textures")
        active_path = os.path.join(car_tex_dir, "base_color.png")
        orig_path = os.path.join(car_tex_dir, "base_color_original.png")
        team_path = os.path.join(car_tex_dir, "base_color_team.png")
        return car_tex_dir, active_path, orig_path, team_path

    def backup_original(self, car_slug: str) -> bool:
        car_tex_dir, active_path, orig_path, _ = self._get_texture_paths(car_slug)
        if not os.path.exists(active_path):
            return False
        if not os.path.exists(orig_path):
            shutil.copyfile(active_path, orig_path)
            return True
        return True

    def apply_team(self, car_slug: str) -> bool:
        _, active_path, orig_path, team_path = self._get_texture_paths(car_slug)
        if not os.path.exists(team_path):
            return False
        # Ensure original is safely backed up before overwriting
        self.backup_original(car_slug)
        shutil.copyfile(team_path, active_path)
        return True

    def restore_original(self, car_slug: str) -> bool:
        _, active_path, orig_path, _ = self._get_texture_paths(car_slug)
        if not os.path.exists(orig_path):
            return False
        shutil.copyfile(orig_path, active_path)
        return True

    def get_status(self, car_slug: str) -> str:
        _, active_path, orig_path, team_path = self._get_texture_paths(car_slug)
        if not os.path.exists(active_path):
            return "missing"
        if os.path.exists(team_path) and filecmp.cmp(active_path, team_path, shallow=False):
            return "team"
        if os.path.exists(orig_path) and filecmp.cmp(active_path, orig_path, shallow=False):
            return "original"
        return "unmodified"

    def apply_all(self):
        count = 0
        for car in ALL_CARS:
            if self.apply_team(car):
                count += 1
                print(f"[APPLY] {car}: Team livery applied.")
            else:
                print(f"[SKIP]  {car}: No team livery texture found.")
        return count

    def restore_all(self):
        count = 0
        for car in ALL_CARS:
            if self.restore_original(car):
                count += 1
                print(f"[RESTORE] {car}: Original manufacturer livery restored.")
            else:
                print(f"[SKIP]    {car}: No original backup found.")
        return count

    def print_status(self):
        print("=" * 60)
        print(f"{'CAR SLUG':22s} | {'CURRENT LIVERY STATUS'}")
        print("-" * 60)
        for car in ALL_CARS:
            status = self.get_status(car)
            print(f"{car:22s} | {status.upper()}")
        print("=" * 60)

def main():
    parser = argparse.ArgumentParser(description="La Voiture GT3 Car Livery & Fallback Manager")
    parser.add_argument("--action", choices=["apply", "restore", "status", "backup"], default="status",
                        help="Action to perform: apply team livery, restore original, or check status")
    parser.add_argument("--car", choices=ALL_CARS, help="Specific car slug to target")
    parser.add_argument("--all", action="store_true", help="Apply action to all 13 cars")
    parser.add_argument("--dir", default="assets/cars", help="Base directory of car assets")
    args = parser.parse_args()

    manager = CarLiveryManager(base_dir=args.dir)

    if args.action == "status":
        if args.car:
            print(f"{args.car}: {manager.get_status(args.car)}")
        else:
            manager.print_status()
    elif args.action == "apply":
        if args.all:
            manager.apply_all()
        elif args.car:
            if manager.apply_team(args.car):
                print(f"Applied team livery to {args.car}.")
            else:
                print(f"Error: Could not apply team livery to {args.car}.", file=sys.stderr)
        else:
            print("Specify --car <slug> or --all.", file=sys.stderr)
    elif args.action == "restore":
        if args.all:
            manager.restore_all()
        elif args.car:
            if manager.restore_original(args.car):
                print(f"Restored original livery to {args.car}.")
            else:
                print(f"Error: Could not restore original livery to {args.car}.", file=sys.stderr)
        else:
            print("Specify --car <slug> or --all.", file=sys.stderr)
    elif args.action == "backup":
        if args.all:
            for car in ALL_CARS:
                manager.backup_original(car)
            print("All cars backed up.")
        elif args.car:
            manager.backup_original(args.car)
            print(f"Backed up {args.car}.")

if __name__ == "__main__":
    main()
