import { Action, ActionPanel, Grid, Icon, Toast, closeMainWindow, showHUD, showToast } from "@raycast/api";
import { useEffect, useState } from "react";
import { theme } from "./theme";

type Wallpaper = { path: string; thumb: string; title: string; current: boolean };

export default function SwitchWallpaper() {
  const [wallpapers, setWallpapers] = useState<Wallpaper[]>();
  const [themeName, setThemeName] = useState("");
  useEffect(() => {
    theme("current").then(setThemeName).catch(() => {});
    theme("wallpaper", "list", "--json")
      .then((out) => setWallpapers(JSON.parse(out)))
      .catch((e: Error) => {
        setWallpapers([]);
        showToast({ style: Toast.Style.Failure, title: "Couldn't list wallpapers", message: e.message });
      });
  }, []);
  const title = themeName.replace(/(^|-)([a-z])/g, (_, d, c) => (d ? " " : "") + c.toUpperCase());

  return (
    <Grid isLoading={!wallpapers} columns={3} aspectRatio="16/9" fit={Grid.Fit.Fill} searchBarPlaceholder={`${title} wallpapers`}>
      <Grid.EmptyView icon={Icon.Image} title={`${title} has no wallpapers`}
        description="Themes without wallpapers keep yours. Switch Theme lists the ones that have some." />
      {wallpapers?.map((w) => (
        <Grid.Item key={w.path} content={{ source: w.thumb }} title={w.title}
          accessory={w.current ? { icon: Icon.Checkmark, tooltip: "Current wallpaper" } : undefined}
          actions={
            <ActionPanel>
              <Action title="Set Wallpaper" icon={Icon.Image} onAction={() => apply(w)} />
              <Action.ShowInFinder path={w.path} />
            </ActionPanel>
          } />
      ))}
    </Grid>
  );
}

async function apply(w: Wallpaper) {
  await closeMainWindow();
  try {
    await showHUD(await theme("wallpaper", "set", w.path));
  } catch (e) {
    await showHUD(`Couldn't set wallpaper: ${(e as Error).message}`);
  }
}
