// Runs hypr-mac's theme script (.local/bin/theme), which does the work; this extension is just its picker.
import { execFile } from "node:child_process";
import { homedir } from "node:os";

export type Theme = {
  name: string;
  title: string;
  source: "hypr-mac" | "git" | "omarchy";
  mode: "dark" | "light";
  current: boolean;
  colors: Record<"background" | "foreground" | "accent" | "red" | "green" | "yellow" | "blue" | "magenta" | "cyan", string>;
};

export function theme(...args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    // Raycast's PATH has no Homebrew; git clones can take a while
    execFile(`${homedir()}/.local/bin/theme`, args, { env: { ...process.env, PATH: "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" }, timeout: 120_000 },
      (error, stdout, stderr) => (error ? reject(new Error(stderr.trim() || error.message)) : resolve(stdout.trim())));
  });
}
