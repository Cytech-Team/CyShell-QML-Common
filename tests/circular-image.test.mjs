import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import test from "node:test";

const execute = promisify(execFile);

test("CyCircularImage releases static and failed probe resources", async () => {
    const directory = mkdtempSync(join(tmpdir(), "cy-circular-image-"));
    try {
        const configDirectory = join(directory, "shell");
        const runtimeDirectory = join(directory, "runtime");
        mkdirSync(configDirectory);
        mkdirSync(runtimeDirectory, { mode: 0o700 });
        for (const name of ["CyCommon", "Common", "Services"])
            symlinkSync(fileURLToPath(new URL(`../${name}`, import.meta.url)), join(configDirectory, name));
        copyFileSync(new URL("qml/circular-image.qml", import.meta.url), join(configDirectory, "shell.qml"));

        const staticImage = join(directory, "static.png");
        const animatedImage = join(directory, "animated.gif");
        writeFileSync(staticImage, Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFUlEQVR4nGP8z8Dwn4GBgYEJRIAwAB8XAgICR7MUAAAAAElFTkSuQmCC", "base64"));
        writeFileSync(animatedImage, Buffer.from("R0lGODlhAgACAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAAAgACAAAIBgABCAQQEAAh+QQBCgABACwAAAAAAgACAIEAAP8AAAAAAAAAAAAIBgABCAQQEAA7", "base64"));

        const { stdout, stderr } = await execute("qs", ["-p", configDirectory], {
            encoding: "utf8",
            timeout: 30000,
            env: {
                ...process.env,
                QT_QPA_PLATFORM: "offscreen",
                CY_CIRCULAR_IMAGE_STATIC: staticImage,
                CY_CIRCULAR_IMAGE_ANIMATED: animatedImage,
                XDG_RUNTIME_DIR: runtimeDirectory,
                XDG_CONFIG_HOME: join(directory, "config"),
                XDG_CACHE_HOME: join(directory, "cache"),
                XDG_STATE_HOME: join(directory, "state"),
                XDG_DATA_HOME: join(directory, "data")
            }
        });
        const output = stdout + stderr;
        assert.match(output, /PASS circular image probe releases static and error resources/);
        assert.doesNotMatch(output, /\b(?:FAIL|ERROR|TypeError|ReferenceError|SyntaxError)\b|Binding loop detected/);
    } catch (error) {
        throw new Error([error.message, error.stdout, error.stderr].filter(Boolean).join("\n"), { cause: error });
    } finally {
        rmSync(directory, { recursive: true, force: true });
    }
});
