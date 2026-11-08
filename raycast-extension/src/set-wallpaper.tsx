import {
  Action,
  ActionPanel,
  Form,
  Grid,
  Icon,
  Toast,
  closeMainWindow,
  getSelectedFinderItems,
  showHUD,
  showToast,
  useNavigation,
} from "@raycast/api";
import { useCallback, useEffect, useState } from "react";
import { theme } from "./theme";

type Wallpaper = { path: string; thumb: string; title: string; source: "theme" | "yours"; current: boolean };

// The current theme's wallpapers, then yours (~/Pictures/Wallpapers); Add Wallpaper Image adds to yours
export default function SetWallpaper() {
  const [wallpapers, setWallpapers] = useState<Wallpaper[]>();
  const [themeName, setThemeName] = useState("");
  const load = useCallback(() => {
    theme("current").then(setThemeName).catch(() => {});
    theme("wallpaper", "list", "--json")
      .then((out) => setWallpapers(JSON.parse(out)))
      .catch((e: Error) => {
        setWallpapers([]);
        showToast({ style: Toast.Style.Failure, title: "Couldn't list wallpapers", message: e.message });
      });
  }, []);
  useEffect(load, [load]);
  const title = themeName.replace(/(^|-)([a-z])/g, (_, d, c) => (d ? " " : "") + c.toUpperCase());
  const add = (
    <Action.Push title="Add Wallpaper Image" icon={Icon.Plus} shortcut={{ modifiers: ["cmd"], key: "n" }}
      target={<AddWallpaperForm onAdded={load} />} />
  );

  return (
    <Grid isLoading={!wallpapers} columns={3} aspectRatio="16/9" fit={Grid.Fit.Fill} searchBarPlaceholder="Search wallpapers">
      <Grid.EmptyView icon={Icon.Image} title="No wallpapers"
        description="Add Wallpaper Image (⌘N) adds images to ~/Pictures/Wallpapers, and some themes bring their own."
        actions={<ActionPanel>{add}</ActionPanel>} />
      {[
        { source: "theme", title: `${title} Wallpapers`, empty: `${title} has none: themes without wallpapers keep yours` },
        { source: "yours", title: "Your Wallpapers", empty: "Add Wallpaper Image (⌘N) adds to ~/Pictures/Wallpapers" },
      ].map((section) => (
        <Grid.Section key={section.source} title={section.title}
          subtitle={wallpapers && !wallpapers.some((w) => w.source === section.source) ? section.empty : undefined}>
          {wallpapers?.filter((w) => w.source === section.source).map((w) => (
            <Grid.Item key={w.path} content={{ source: w.thumb }} title={w.title}
              accessory={w.current ? { icon: Icon.Checkmark, tooltip: "Current wallpaper" } : undefined}
              actions={
                <ActionPanel>
                  <Action title="Set Wallpaper" icon={Icon.Image} onAction={() => apply(w)} />
                  {add}
                  <Action.ShowInFinder path={w.path} />
                </ActionPanel>
              } />
          ))}
        </Grid.Section>
      ))}
    </Grid>
  );
}

async function apply(w: Wallpaper) {
  await closeMainWindow();
  try {
    // the theme's: picked for this theme; yours: kept up through theme changes
    await showHUD(await theme("wallpaper", w.source === "theme" ? "set" : "keep", w.path));
  } catch (e) {
    await showHUD(`Couldn't set wallpaper: ${(e as Error).message}`);
  }
}

// A file, or a path or image URL (prefilled with the image selected in Finder): added to yours and set, kept through
// theme changes
function AddWallpaperForm({ onAdded }: { onAdded: () => void }) {
  const { pop } = useNavigation();
  const [busy, setBusy] = useState(false);
  const [source, setSource] = useState("");
  useEffect(() => {
    getSelectedFinderItems()
      .then((items) => items[0] && /\.(jpe?g|png|heic|webp|tiff|gif)$/i.test(items[0].path) && setSource(items[0].path))
      .catch(() => {});
  }, []);

  return (
    <Form
      isLoading={busy}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Add and Set Wallpaper" icon={Icon.Plus}
            onSubmit={async ({ file }: { file: string[] }) => {
              const src = file[0] ?? source.trim();
              if (!src) {
                await showToast({ style: Toast.Style.Failure, title: "Pick a file or give a path or URL" });
                return;
              }
              setBusy(true);
              const toast = await showToast({ style: Toast.Style.Animated, title: "Adding wallpaper image" });
              try {
                toast.style = Toast.Style.Success;
                toast.title = await theme("wallpaper", "keep", src);
                onAdded();
                pop();
              } catch (e) {
                toast.style = Toast.Style.Failure;
                toast.title = "Couldn't add wallpaper image";
                toast.message = (e as Error).message;
              } finally {
                setBusy(false);
              }
            }} />
        </ActionPanel>
      }
    >
      <Form.FilePicker id="file" title="File" allowMultipleSelection={false} canChooseDirectories={false} />
      <Form.TextField id="source" title="Or Path / URL" placeholder="https://… or ~/Downloads/wall.jpg"
        value={source} onChange={setSource} />
      <Form.Description text="Added to ~/Pictures/Wallpapers (a URL is downloaded) and set, kept up when you switch themes." />
    </Form>
  );
}
