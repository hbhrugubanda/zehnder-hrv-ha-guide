# Zehnder ComfoAir Q + Home Assistant

**A short guide to connecting a Zehnder ComfoAir Q heat recovery unit to Home Assistant, and what you can do with it once it's there.**

Repository: <https://github.com/hbhrugubanda/zehnder-hrv-ha-guide>

---

## What this assumes

You already have all of this working:

- A **Zehnder ComfoAir Q** (Q350 / Q450 / Q600), installed and running.
- A **[ComfoConnect LAN C](#1a-the-comfoconnect-lan-c)** or **[ComfoConnect Pro](#1b-the-comfoconnect-pro)** — the small Zehnder device that puts the unit on your network — plugged in and working in the Zehnder app.
- A running **Home Assistant**, and you know that device's IP address.

If the Zehnder app can see your unit, you have everything you need. This guide covers only the Home Assistant side, and it is written for the LAN C — section 1b covers what changes on a Pro.

Everything below was read off a live LAN C install rather than copied from documentation. Where something has *not* been verified, it says so.

---

## 1a. The ComfoConnect LAN C

The ComfoAir Q has no network connection of its own. The **ComfoConnect LAN C** is the small separate box that gives it one — it wires into the unit at one end and into your network at the other. Home Assistant talks to that box, not to the unit itself, and it all happens on your own network with nothing going via Zehnder's servers.

Two things are worth sorting before you start:

- **Give it a fixed address.** Home Assistant is told the LAN C's IP address once and never looks it up again. Find it in your router's list of connected devices, then set a **DHCP reservation** so it can't change later.
- **Keep its client list short.** Only a handful of things can be registered to it at once — phone app, tablet, Home Assistant. If Home Assistant drops out whenever you open the Zehnder app, remove registrations you no longer use.

Zehnder now sells the **ComfoConnect Pro** in its place. Different box, different setup — see *[section 1b](#1b-the-comfoconnect-pro)*.

---

## 1b. The ComfoConnect Pro

The **ComfoConnect Pro** is what Zehnder sells now instead of the LAN C. Same idea — it joins the unit to your network — but it is a different device, and **section 2 does not apply to it**. Home Assistant's built-in integration only speaks the LAN C's language.

**It has to be set up first, and it doesn't arrive ready.** Press the **AP** button, join the temporary **ComfoConnectPro** Wi-Fi network it creates (password on the device label), and open **http://comfoconnectpro.local** in a browser. From there, put it on your home network — ethernet or Wi-Fi — and give it a fixed address in your router.

Then, on that same web page, go to **Protocols & Services** and switch the protocol to **Modbus TCP**. Leave the defaults alone: slave ID 1, port 502. Nothing in Home Assistant can see the Pro until that is on.

**Modbus is how Home Assistant talks to it.** Two routes, both fine:

- **[hstrohmaier/ha_comfoconnectpro](https://github.com/hstrohmaier/ha_comfoconnectpro)**, installed through HACS as a custom repository. Asks for the address, slave ID and port, and does the rest. Written against a ComfoAir Q350.
- **Home Assistant's own Modbus integration**, which is built in. More setting up — you list the values you want yourself — but nothing third-party involved.

The Pro can do things the LAN C can't, including away mode, a timed boost and a temperature target. It doesn't report fan speeds or electricity use, so the Energy dashboard trick in section 5 has no equivalent.

> **Researched, not tested.** The rest of this guide was written against a live LAN C. This section comes from Zehnder's own [ComfoConnect PRO installer manual](https://zehnder.lv/wp-content/uploads/2024/12/ComfoConnect-PRO-Installer-manual.pdf), which documents the setup and the full Modbus interface — so the details are Zehnder's, but nobody has yet proved the round trip to Home Assistant end to end. Corrections welcome.

---

## 2. Connect it to Home Assistant

*This section is the LAN C route. On a Pro, follow section 1b instead.*

**You do not need HACS — the community store other guides send you to — and there is nothing for you to install.** An integration called **[Zehnder ComfoAir Q](https://www.home-assistant.io/integrations/comfoconnect/)** already ships with Home Assistant — it is part of Home Assistant itself, which is why it has a page on the official documentation site rather than a repository you add. What throws people is that it is also one of the few with **no setup screen** — you won't find it under *Settings → Devices & Services*, because you add it by editing a text file and restarting instead. That combination is unusual, but it's expected, not a mistake.

**Take a backup first** — *Settings → System → Backups*. You are about to edit the file Home Assistant reads on startup, and a stray space in it can stop Home Assistant starting.

Now open `configuration.yaml` and add the block below to the bottom of it, changing the IP to your Zehnder device's. The easiest way in is the **File editor** app under *Settings → Apps*; if you don't have it, install it from that screen first. (Running Home Assistant in Docker or a Python environment? You won't have Apps — edit the file however you normally reach it.)

```yaml
comfoconnect:
  host: 192.168.1.50
  name: ComfoAirQ

sensor:
  - platform: comfoconnect
    resources:
      - current_temperature
      - current_humidity
      - current_rmot
      - outside_temperature
      - outside_humidity
      - supply_temperature
      - supply_humidity
      - supply_fan_speed
      - supply_fan_duty
      - air_flow_supply
      - exhaust_temperature
      - exhaust_humidity
      - exhaust_fan_speed
      - exhaust_fan_duty
      - air_flow_exhaust
      - bypass_state
      - days_to_replace_filter
      - power_usage
      - power_total
      - preheater_power_usage
      - preheater_power_total
```

Then:

1. **Developer tools → YAML → Check configuration.** Fix anything it flags — the error names the line.
2. **Settings → System →** power icon → **Restart Home Assistant.**
3. **Developer tools → States**, filter for `comfoairq`. You should see one `fan.comfoairq` and twenty-one sensors with live numbers.

Those are your **entities** — Home Assistant's word for one controllable thing or one reading. Each has an **entity ID** like `sensor.comfoairq_inside_temperature`, and that ID is what you point automations and dashboards at for the rest of this guide.

Three notes:

- If `sensor:` already exists at the far left of your file, don't add a second one. Move just the `- platform: comfoconnect` part underneath the existing `sensor:` line.
- `name: ComfoAirQ` decides what every entity is called. Leave it alone and every example below works as written.
- Any later change to this block needs another **restart**, not a YAML reload.

---

## 3. What you get

One control and twenty-one readings.

### The control

`fan.comfoairq` is the unit itself. It has four speeds, matching the wall controller — there is no 50%.

| Setting | Percentage |
|---|---|
| Away | `0` |
| Low | `33` |
| Medium | `66` |
| High | `100` |

Setting a percentage puts the unit into **manual** mode and leaves it there. Setting the preset back to `auto` hands control back to the unit's own schedule. `auto` is the only preset available.

### The four air streams

Your unit is an **MVHR** — mechanical ventilation with heat recovery. It moves air along four paths at once, and warms the incoming air with heat taken from the outgoing air. Understanding those four paths is what turns a wall of numbers into something useful.

One naming quirk to know first: Zehnder's manuals call the air pulled out of your rooms **extract** air, while Home Assistant calls it **inside** and keeps **exhaust** for the air leaving the building.

| Stream | Meaning | Temperature | Humidity | Live |
|---|---|---|---|---|
| **Outside** | Fresh air arriving from outdoors | `sensor.comfoairq_outside_temperature` | `sensor.comfoairq_outside_humidity` | 12.7 °C · 85% |
| **Supply** | Warmed fresh air blown into your rooms | `sensor.comfoairq_supply_temperature` | `sensor.comfoairq_supply_humidity` | 18.3 °C · 62% |
| **Inside** | Stale air pulled out of kitchen and bathrooms | `sensor.comfoairq_inside_temperature` | `sensor.comfoairq_inside_humidity` | 18.8 °C · 59% |
| **Exhaust** | Spent air leaving the building, heat removed | `sensor.comfoairq_exhaust_temperature` | `sensor.comfoairq_exhaust_humidity` | 13.8 °C · 79% |

> Read those together. Outside air arrived at 12.7 °C and reached the rooms at 18.3 °C. Inside air left the rooms at 18.8 °C and exited the building at 13.8 °C. The unit moved about 5.6 degrees of warmth from the outgoing air into the incoming air, for 43 watts of fan power. That comparison is the clearest picture of heat recovery you'll get, and it's the main reason to put this in Home Assistant at all.

### Everything else

| Entity | What it tells you | Unit |
|---|---|---|
| `sensor.comfoairq_supply_airflow` | Fresh air delivered | m³/h |
| `sensor.comfoairq_exhaust_airflow` | Stale air removed | m³/h |
| `sensor.comfoairq_supply_fan_speed` | Supply fan revolutions | rpm |
| `sensor.comfoairq_exhaust_fan_speed` | Extract fan revolutions | rpm |
| `sensor.comfoairq_supply_fan_duty` | How hard the supply fan works | % |
| `sensor.comfoairq_exhaust_fan_duty` | How hard the extract fan works | % |
| `sensor.comfoairq_bypass_state` | How far the summer bypass is open (0 closed, 100 open) | % |
| `sensor.comfoairq_days_to_replace_filter` | Days until filters are due | d |
| `sensor.comfoairq_current_rmot` | Running mean outdoor temperature — a rolling average the unit uses to decide the season has changed | °C |
| `sensor.comfoairq_power_usage` | Current electricity draw | W |
| `sensor.comfoairq_energy_total` | Lifetime electricity used | kWh |
| `sensor.comfoairq_preheater_power_usage` | Frost preheater draw, zero unless genuinely cold | W |
| `sensor.comfoairq_preheater_energy_total` | Lifetime preheater electricity | kWh |

### What it can't do

The integration is read-mostly. Worth knowing before you plan anything on top of it.

- **The bypass is read-only.** You can see how far it's open, not move it.
- **No away or holiday switch.** Closest equivalent is setting the fan to 0%.
- **No filter reset.** Still done at the wall controller or in the Zehnder app.
- **No comfort profiles or temperature targets.** Those stay on the unit.
- **One preset only** — `auto`.

---

## 4. Automation ideas

This is where the unit gets smarter than its wall controller.

None of these are recipes to copy. Each is one trigger and one or two actions, built under **Settings → Automations & Scenes → Create automation** with the visual editor — no YAML needed. Two entities do nearly all the work:

- **`fan.comfoairq`** — the unit itself. Either *set percentage* (33 Low, 66 Medium, 100 High) or *set preset mode* back to `auto`.
- **`sensor.comfoairq_*`** — the numbers you trigger on.

> **The one rule.** Setting a percentage takes the unit out of automatic mode and leaves it there. Every boost must finish by setting the preset back to `auto`, or the unit sits at that speed indefinitely.

### Boost when the air gets humid

The most useful one by a distance, and it needs no extra hardware — it runs off the unit's own extract humidity sensor.

**When** `sensor.comfoairq_inside_humidity` stays above 70% for five minutes → **run** the fan at 100% → **wait** until it drops back below 63%, giving up after an hour → **set preset to `auto`**.

**Picking your numbers.** That sensor measures the air being pulled out of your wet rooms, so it rises whenever anyone showers, cooks or dries laundry — one trigger covering the whole house. But it is a blend of every extract point, so it moves more slowly and less sharply than a sensor sitting in the bathroom itself.

Set the thresholds against your own baseline rather than copying mine. Click the sensor in Home Assistant, look at a week of history, and note where it normally sits — on the reference unit that's around 59%. Trigger roughly 10 points above that, and release about 4 points above it. Hence 70% and 63%. If the boost never fires, lower the trigger; if it fires while nothing is happening, raise it.

Two other details worth keeping: the five minute delay on the trigger stops a brief blip causing a boost, and setting the automation's run mode to **Restart** means a second shower mid-boost restarts the timer rather than the automation refusing to run.

A humidity sensor in the bathroom itself is the upgrade here — it reacts within seconds rather than minutes. Use it in place of the extract sensor if you add one.

### Boost while the rangehood runs

An idea rather than a recipe, and the most useful one if your hood recirculates. A recirculating hood filters grease and some odour, then blows the air straight back into the room — the smells never leave the house. Boosting the unit while the hood runs gives them somewhere to go. Whether that is worth automating depends on your kitchen.

**When** the rangehood switches on → **run** the fan at 100% → **wait** until it switches off, giving up after two hours → **wait** a further 15 minutes → **set preset to `auto`**.

The run-on does most of the work — smells outlast the cooking. The two hour cutoff means a hood left on all day cannot strand the unit at full speed.

**If your rangehood isn't smart**, and most aren't, trigger on a power-monitoring smart plug instead: boost when its power sensor goes above roughly 20 W and release below 10 W, adjusted to whatever the hood actually draws. The hood light works as a rougher proxy.

Two things worth knowing before you rely on it. The unit raises supply and extract together, so you cannot boost incoming air alone from Home Assistant — a boost moves more air both ways. And if your hood is **ducted** rather than recirculating, it already extracts far more than the unit can, so the boost adds little; in a house with an open-flued appliance, a powerful ducted hood is a backdraft question for a heating engineer rather than something an automation addresses. Either way, never duct a rangehood into the MVHR — the grease has nowhere good to go.

### Wind down when the house is empty

Two small automations rather than one.

**When** the number of people in `zone.home` drops below 1 for ten minutes → **run** the fan at 33%.

**When** it rises above 0 → **set preset to `auto`**.

Both need Home Assistant to know who's home — the companion app on at least one phone with location sharing on. Without that, skip them.

### Summer night purge

Pull cool night air through the house, but only when outside is genuinely cooler than inside.

**At** 22:00, **if** `sensor.comfoairq_inside_temperature` is above 23 °C **and** `sensor.comfoairq_outside_temperature` is below the inside temperature → **run** the fan at 100% for three hours → **set preset to `auto`**.

That second condition compares one sensor against another rather than against a fixed number — Home Assistant accepts an entity in place of a value. It is what stops the automation running on a warm night and making things worse.

### Filter reminder

**When** `sensor.comfoairq_days_to_replace_filter` drops below 14 → **send** yourself a notification and **add** a filter set to the shopping list.

Find your own notification action under **Developer tools → Actions** by typing `notify` — the name depends on which phone has the companion app installed.

### Further ideas, sketched

Things the sensors support that are worth building once the basics work:

- **CO₂ boost** — if you own an air quality sensor, boost on CO₂ rather than humidity. Better proxy for "too many people in here".
- **Quiet overnight** — drop to Low at bedtime, back to `auto` in the morning. Worth it if the unit is audible in a bedroom.
- **Pollen or poor air quality outside** — drop to Low when an outdoor air quality sensor spikes, so you pull in less of it.
- **Frost warning** — notify when `preheater_power_usage` goes above zero for a sustained period. It means the unit is spending real electricity fighting the cold.
- **Bypass watch** — you can't control the bypass, but you can chart `bypass_state` against indoor and outdoor temperature to see whether the unit's own logic is behaving.
- **Efficiency tracking** — a template sensor comparing supply, outside and inside temperatures gives you a live heat recovery percentage to trend over months.
- **Filter life on the Energy dashboard** — pair filter days with `power_usage`; a clogging filter shows up as rising fan duty for the same airflow.

---

## 5. Putting it on a dashboard

Every entity is on a dashboard already — Home Assistant builds one automatically — so this is about arranging them rather than getting them to appear. Build what suits you; a few pointers on what works well for a ventilation unit:

- **The fan tile.** A tile card on `fan.comfoairq` with the *fan speed* feature gives you the whole control surface: current speed, and four buttons to change it.
- **Temperatures side by side.** A glance card with outside, supply, inside and exhaust in that order reads as the journey air takes through the unit, left to right.
- **A history graph is the one to keep.** Put supply, outside and inside temperature on one 24-hour graph. The gap between the outside line and the supply line *is* your heat recovery, drawn over time — the single most satisfying thing this integration gives you.
- **Everything else on an entities card.** Airflow, humidity, bypass state, power draw, filter days. Useful to have, not worth a card each.

### Energy dashboard

`sensor.comfoairq_energy_total` is a proper lifetime energy meter, so the Energy dashboard takes it directly: **Settings → Dashboards → Energy → Individual devices → Add device**.

Add `sensor.comfoairq_preheater_energy_total` as a second device if you want the frost preheater separately. In a cold snap it can dwarf the fans.

---

## 6. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Home Assistant won't start after the edit | YAML indentation — a tab, or wrong number of spaces | Restore the backup, re-copy the block rather than retyping it |
| No `comfoairq` entities at all | Wrong IP, or the Zehnder device is on a different network segment | Confirm the address, check the LAN C's link light |
| Config check fails naming a resource | Mistyped resource key | Copy the block in section 2 again rather than retyping it — several keys aren't what you'd guess |
| Fan appears but sensors don't | The `sensor:` block was missed, or a second `sensor:` key overwrote the first | Confirm `sensor:` appears exactly once at the far left of the file |
| Worked, then stopped weeks later | The Zehnder device's IP changed | Set a DHCP reservation for the LAN C in your router |
| Drops out when the Zehnder app is opened | The Zehnder device allows a limited number of registered clients | Remove unused device registrations in the Zehnder app, restart Home Assistant *(commonly reported, not tested here)* |
| Fan stuck at one speed | An automation set a percentage and never handed control back | Call `fan.set_preset_mode` with `auto` from **Developer tools → Actions**, then fix the automation |

---

## A printable copy

If you'd rather have this as a PDF to keep or pass on, clone the repository and run:

```
./build-pdf.sh
```

The finished file lands in `build/`.

---

*Written against a live ComfoConnect LAN C paired to a ComfoAir Q. Entity IDs, resource keys, units and sample values were read from that installation rather than transcribed from documentation. The ComfoConnect Pro section is drawn from Zehnder's published installer manual rather than from a tested install, and is marked as such.*

*Not affiliated with or endorsed by Zehnder. Check your unit's warranty terms before changing how it is controlled.*
