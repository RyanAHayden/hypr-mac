import { showHUD } from "@raycast/api";
import { theme } from "./theme";

export default async function NextWallpaper() {
  try {
    await showHUD(await theme("wallpaper", "next"));
  } catch (e) {
    await showHUD((e as Error).message);
  }
}
