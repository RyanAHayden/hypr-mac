import {
  Action,
  ActionPanel,
  Alert,
  Color,
  Form,
  Icon,
  List,
  Toast,
  closeMainWindow,
  confirmAlert,
  showHUD,
  showToast,
  useNavigation,
} from "@raycast/api";
import { useCallback, useEffect, useState } from "react";
import { Theme, theme } from "./theme";

const SWATCHES = ["red", "green", "yellow", "blue", "magenta", "cyan"] as const;
const SECTIONS = [
  { title: "Yours", sources: ["hypr-mac", "git"] },
  { title: "Omarchy", sources: ["omarchy"] },
];

export default function SwitchTheme() {
  const [themes, setThemes] = useState<Theme[]>();
  const [keepWallpaper, setKeepWallpaper] = useState(false);
  const load = useCallback(() => {
    theme("wallpaper").then((mode) => setKeepWallpaper(mode === "keep")).catch(() => {});
    theme("list", "--json")
      .then((out) => setThemes(JSON.parse(out)))
      .catch((e: Error) => {
        setThemes([]);
        showToast({ style: Toast.Style.Failure, title: "Couldn't list themes", message: e.message });
      });
  }, []);
  useEffect(load, [load]);

  return (
    <List isLoading={!themes} searchBarPlaceholder="Search themes">
      {SECTIONS.map((section) => (
        <List.Section key={section.title} title={section.title}>
          {themes
            ?.filter((t) => section.sources.includes(t.source))
            .map((t) => <ThemeItem key={t.name} theme={t} reload={load} keepWallpaper={keepWallpaper} />)}
        </List.Section>
      ))}
    </List>
  );
}

function ThemeItem({ theme: t, reload, keepWallpaper }: { theme: Theme; reload: () => void; keepWallpaper: boolean }) {
  return (
    <List.Item
      title={t.title}
      icon={{ source: Icon.CircleFilled, tintColor: t.colors.accent }}
      keywords={[t.name, t.mode]}
      accessories={[
        ...(t.current ? [{ icon: { source: Icon.Checkmark, tintColor: Color.Green }, tooltip: "Current theme" }] : []),
        ...(t.mode === "light" ? [{ tag: { value: "Light", color: Color.Yellow } }] : []),
        ...SWATCHES.map((c) => ({ icon: { source: Icon.CircleFilled, tintColor: t.colors[c] }, tooltip: `${c} ${t.colors[c]}` })),
      ]}
      actions={
        <ActionPanel>
          <Action title="Switch to Theme" icon={Icon.Brush} onAction={() => apply(t)} />
          <Action.Push title="Install Theme from Git" icon={Icon.Download} target={<InstallForm onInstalled={reload} />}
            shortcut={{ modifiers: ["cmd"], key: "n" }} />
          {t.source === "git" && (
            <Action title="Remove Theme" icon={Icon.Trash} style={Action.Style.Destructive}
              shortcut={{ modifiers: ["ctrl"], key: "x" }} onAction={() => remove(t, reload)} />
          )}
          <Action title={keepWallpaper ? "Use Theme Wallpapers" : "Keep My Wallpaper"} icon={Icon.Image}
            shortcut={{ modifiers: ["cmd"], key: "b" }} onAction={() => toggleWallpaper(reload)} />
          <Action title="Update Themes" icon={Icon.ArrowClockwise} shortcut={{ modifiers: ["cmd"], key: "r" }}
            onAction={() => update(reload)} />
        </ActionPanel>
      }
    />
  );
}

async function apply(t: Theme) {
  await closeMainWindow();
  try {
    await showHUD(await theme("set", t.name));
  } catch (e) {
    await showHUD(`Couldn't switch theme: ${(e as Error).message}`);
  }
}

async function toggleWallpaper(reload: () => void) {
  try {
    await showToast({ style: Toast.Style.Success, title: await theme("wallpaper", "toggle") });
    reload();
  } catch (e) {
    await showToast({ style: Toast.Style.Failure, title: "Couldn't change the wallpaper setting", message: (e as Error).message });
  }
}

async function remove(t: Theme, reload: () => void) {
  if (!(await confirmAlert({ title: `Remove ${t.title}?`, message: "Deletes its clone; install it again from git to get it back.",
    primaryAction: { title: "Remove", style: Alert.ActionStyle.Destructive } }))) return;
  try {
    await showToast({ style: Toast.Style.Success, title: await theme("remove", t.name) });
    reload();
  } catch (e) {
    await showToast({ style: Toast.Style.Failure, title: "Couldn't remove theme", message: (e as Error).message });
  }
}

async function update(reload: () => void) {
  const toast = await showToast({ style: Toast.Style.Animated, title: "Updating themes" });
  try {
    await theme("update");
    toast.style = Toast.Style.Success;
    toast.title = "Themes updated";
    reload();
  } catch (e) {
    toast.style = Toast.Style.Failure;
    toast.title = "Couldn't update themes";
    toast.message = (e as Error).message;
  }
}

function InstallForm({ onInstalled }: { onInstalled: () => void }) {
  const { pop } = useNavigation();
  const [busy, setBusy] = useState(false);
  return (
    <Form
      isLoading={busy}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Install and Switch" icon={Icon.Download} onSubmit={async ({ url }: { url: string }) => {
            setBusy(true);
            const toast = await showToast({ style: Toast.Style.Animated, title: "Installing theme" });
            try {
              toast.style = Toast.Style.Success;
              toast.title = await theme("install", url.trim());
              onInstalled();
              pop();
            } catch (e) {
              toast.style = Toast.Style.Failure;
              toast.title = "Couldn't install theme";
              toast.message = (e as Error).message;
            } finally {
              setBusy(false);
            }
          }} />
        </ActionPanel>
      }
    >
      <Form.TextField id="url" title="Git URL" placeholder="https://github.com/someone/omarchy-something-theme" />
      <Form.Description text="Any Omarchy theme repo, or the whole omarchy-theme-install line from omarchy.org. It's cloned into ~/.config/omarchy/themes and switched to." />
    </Form>
  );
}
