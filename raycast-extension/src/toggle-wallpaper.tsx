import { showHUD } from "@raycast/api";
import { theme } from "./theme";

export default async function ToggleWallpaper() {
  try {
    await showHUD(await theme("wallpaper", "toggle"));
  } catch (e) {
    await showHUD(`Couldn't change the wallpaper setting: ${(e as Error).message}`);
  }
}
