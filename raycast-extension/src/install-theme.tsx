import { LaunchProps, Toast, showHUD, showToast } from "@raycast/api";
import { theme } from "./theme";

export default async function InstallTheme(props: LaunchProps<{ arguments: { url: string } }>) {
  const toast = await showToast({ style: Toast.Style.Animated, title: "Installing theme" });
  try {
    await showHUD(await theme("install", props.arguments.url.trim()));
  } catch (e) {
    toast.style = Toast.Style.Failure;
    toast.title = "Couldn't install theme";
    toast.message = (e as Error).message;
  }
}
