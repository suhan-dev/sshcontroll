# Tailscale Setup For Fast Saves

SSHcontroll uses SSH and rsync for file save/upload. Tailscale is only the
network route, but route quality has a huge effect on video and folder transfer
speed.

## Goal

The fastest normal setup is:

```text
C computer -> Tailscale direct path -> A computer
```

Avoid this when possible:

```text
C computer -> distant DERP relay -> A computer
```

DERP relay is useful for connectivity, but it can reduce transfer speed enough
that an 80 MB video feels broken.

## Check Both Macs

On C:

```bash
tailscale status
tailscale ping <A-tailnet-name-or-ip>
```

On A:

```bash
tailscale status
tailscale ping <C-tailnet-name-or-ip>
```

If `tailscale` is not on PATH on macOS, use:

```bash
/Applications/Tailscale.app/Contents/MacOS/Tailscale status
/Applications/Tailscale.app/Contents/MacOS/Tailscale ping <other-mac-tailnet-name-or-ip>
```

Good output usually includes `direct` and a nearby/local endpoint. Slow output
often mentions a DERP region, relay, exit node, VPN path, or far-away country.

## Prefer Direct LAN Discovery

When both Macs are on the same Wi-Fi/LAN:

1. Keep Tailscale running on both Macs.
2. Disable exit-node usage unless it is intentionally needed.
3. Avoid forcing all traffic through another country.
4. Keep macOS firewall/VPN settings from blocking local UDP peer discovery.
5. Run `tailscale ping` again and confirm it moves to `direct`.

Useful reset commands:

```bash
tailscale set --exit-node=
tailscale set --accept-routes=false
tailscale set --shields-up=false
```

Run the equivalent commands through the full app path if needed:

```bash
/Applications/Tailscale.app/Contents/MacOS/Tailscale set --exit-node=
```

## SSHcontroll Settings

In SSHcontroll `Settings`:

- `SSH Target`: use the Tailscale hostname/IP or an SSH config alias that points
  to it.
- `Latency Target`: set the A computer's tailnet hostname/IP for quick checks.
- `Start Tailscale on C when SSHcontroll opens`: keep enabled if you normally
  use Tailscale.

After network changes, press:

1. `Start C Tailscale`
2. `Check Connection`
3. Try saving the same large file again

## When Speed Is Still Low

Check in this order:

1. `tailscale ping` says direct or relay.
2. A is awake and not throttling network.
3. The file is not simultaneously previewing and saving.
4. No exit node or VPN is forcing another country.
5. SSH outside the app has similar or different speed.
6. The remote disk is not full.
7. Wi-Fi signal is stable on both Macs.

For video files, use `Save` and open the local copy. SSHcontroll intentionally
does not load large video previews because preview transfer competes with the
save transfer.
