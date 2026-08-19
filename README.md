# Zehnder ComfoAir Q + Home Assistant

**A short guide to connecting a Zehnder ComfoAir Q heat recovery unit to Home Assistant, and what you can do with it once it's there.**

Repository: <https://github.com/hbhrugubanda/zehnder-hrv-ha-guide>

---

## What this assumes

You already have all of this working:

- A **Zehnder ComfoAir Q** (Q350 / Q450 / Q600), installed and running.
- A **ComfoConnect LAN C** gateway, plugged in, on your network, and working in the Zehnder app.
- A running **Home Assistant**, and you know the LAN C's IP address.

If the Zehnder app can see your unit, you have everything you need. This guide covers only the Home Assistant side.

Everything below was read off a live LAN C install rather than copied from documentation. Where something has *not* been verified, it says so.

---

## 1. Connect it to Home Assistant

The Zehnder integration is one of the few in Home Assistant with **no setup screen**. You add it by editing a text file and restarting. That's expected, not a mistake.

Open `configuration.yaml` (the **File editor** app under *Settings → Apps* is the easiest route) and add this to the bottom. Change the IP to your gateway's.

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

Take a backup before your first edit (*Settings → System → Backups*). YAML is fussy about indentation, and a bad edit can stop Home Assistant starting.

Two notes:

- If `sensor:` already exists at the far left of your file, don't add a second one. Move just the `- platform: comfoconnect` part underneath the existing `sensor:` line.
- `name: ComfoAirQ` decides what every entity is called. Leave it alone and every example below works as written.
- Any later change to this block needs another **restart**, not a YAML reload.

### The naming traps

Six resource keys don't match the entity name you end up with. The block above already has them right — this table is for when you're debugging, or adding one back later.

| What you'd guess | What you must type | Entity you get |
|---|---|---|
| `inside_temperature` | `current_temperature` | `sensor.comfoairq_inside_temperature` |
| `inside_humidity` | `current_humidity` | `sensor.comfoairq_inside_humidity` |
| `supply_airflow` | `air_flow_supply` | `sensor.comfoairq_supply_airflow` |
| `exhaust_airflow` | `air_flow_exhaust` | `sensor.comfoairq_exhaust_airflow` |
| `energy_total` | `power_total` | `sensor.comfoairq_energy_total` |
| `preheater_energy_total` | `preheater_power_total` | `sensor.comfoairq_preheater_energy_total` |

Also worth knowing: Zehnder's manuals call the air leaving your rooms **extract** air. Home Assistant calls it **inside**, and uses **exhaust** for air leaving the building.

---

## 2. What you get

One control and twenty-one readings. Sample values are live readings from the reference unit, so you can see what normal looks like.

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

An MVHR unit moves air along four paths at once. This is the part worth understanding — it turns a wall of numbers into something useful.

| Stream | Meaning | Temperature | Humidity | Live |
|---|---|---|---|---|
| **Outside** | Fresh air arriving from outdoors | `sensor.comfoairq_outside_temperature` | `sensor.comfoairq_outside_humidity` | 12.7 °C · 85% |
| **Supply** | Warmed fresh air blown into your rooms | `sensor.comfoairq_supply_temperature` | `sensor.comfoairq_supply_humidity` | 18.3 °C · 62% |
| **Inside** | Stale air pulled out of kitchen and bathrooms | `sensor.comfoairq_inside_temperature` | `sensor.comfoairq_inside_humidity` | 18.8 °C · 59% |
| **Exhaust** | Spent air leaving the building, heat removed | `sensor.comfoairq_exhaust_temperature` | `sensor.comfoairq_exhaust_humidity` | 13.8 °C · 79% |

> Read those together. Outside air arrived at 12.7 °C and reached the rooms at 18.3 °C. Inside air left the rooms at 18.8 °C and exited the building at 13.8 °C. The unit moved about 5.6 degrees of warmth from the outgoing air into the incoming air, for 43 watts of fan power. That comparison is the clearest picture of heat recovery you'll get, and it's the main reason to put this in Home Assistant at all.

### Everything else

| Entity | What it tells you | Unit | Live |
|---|---|---|---|
| `sensor.comfoairq_supply_airflow` | Fresh air delivered | m³/h | 235 |
| `sensor.comfoairq_exhaust_airflow` | Stale air removed | m³/h | 236 |
| `sensor.comfoairq_supply_fan_speed` | Supply fan revolutions | rpm | 1900 |
| `sensor.comfoairq_exhaust_fan_speed` | Extract fan revolutions | rpm | 1811 |
| `sensor.comfoairq_supply_fan_duty` | How hard the supply fan works | % | 52 |
| `sensor.comfoairq_exhaust_fan_duty` | How hard the extract fan works | % | 50 |
| `sensor.comfoairq_bypass_state` | How far the summer bypass is open (0 closed, 100 open) | % | 0 |
| `sensor.comfoairq_days_to_replace_filter` | Days until filters are due | d | 132 |
| `sensor.comfoairq_current_rmot` | Running mean outdoor temperature — a rolling average the unit uses to decide the season has changed | °C | 13.5 |
| `sensor.comfoairq_power_usage` | Current electricity draw | W | 43 |
| `sensor.comfoairq_energy_total` | Lifetime electricity used | kWh | 564 |
| `sensor.comfoairq_preheater_power_usage` | Frost preheater draw, zero unless genuinely cold | W | 0 |
| `sensor.comfoairq_preheater_energy_total` | Lifetime preheater electricity | kWh | 0 |

### What it can't do

The integration is read-mostly. Worth knowing before you plan anything on top of it.

- **The bypass is read-only.** You can see how far it's open, not move it.
- **No away or holiday switch.** Closest equivalent is setting the fan to 0%.
- **No filter reset.** Still done at the wall controller or in the Zehnder app.
- **No comfort profiles or temperature targets.** Those stay on the unit.
- **One preset only** — `auto`.

---

## 3. Automation ideas

This is where the unit gets smarter than its wall controller.

For each one: **Settings → Automations & Scenes → Create automation → Create new automation**, then the three-dot menu top-right → **Edit in YAML**. Delete what's there, paste, save.

> **The one rule.** Any automation that sets a percentage takes the unit out of automatic mode and leaves it there. Always finish by setting the preset back to `auto`, or the unit sits at that speed indefinitely.

### Boost when the air gets humid

The most useful one by a distance, and it needs no extra hardware — it runs off the unit's own extract humidity sensor.

```yaml
alias: Ventilation - Boost when indoor humidity climbs
description: Runs the unit at full speed while extract humidity is high, then returns control to the unit.
mode: restart
triggers:
  - trigger: numeric_state
    entity_id: sensor.comfoairq_inside_humidity
    above: 70
    for: "00:05:00"
actions:
  - action: fan.set_percentage
    target:
      entity_id: fan.comfoairq
    data:
      percentage: 100
  - wait_for_trigger:
      - trigger: numeric_state
        entity_id: sensor.comfoairq_inside_humidity
        below: 63
    timeout: "01:00:00"
    continue_on_timeout: true
  - action: fan.set_preset_mode
    target:
      entity_id: fan.comfoairq
    data:
      preset_mode: auto
```

**Picking your numbers.** `sensor.comfoairq_inside_humidity` measures the air being pulled out of your wet rooms, so it rises whenever anyone showers, cooks or dries laundry — one trigger covering the whole house. But it is a blend of every extract point, so it moves more slowly and less sharply than a sensor sitting in the bathroom itself.

Set the thresholds against your own baseline rather than copying mine. Click the sensor in Home Assistant, look at a week of history, and note where it normally sits — on the reference unit that's around 59%. Trigger roughly 10 points above that, and release about 4 points above it. Hence `above: 70` and `below: 63`. If the boost never fires, lower the trigger; if it fires while nothing is happening, raise it.

Two other details worth keeping: `for: "00:05:00"` stops a brief blip from triggering a boost, and `mode: restart` means a second shower mid-boost restarts the timer instead of the automation refusing to run.

A humidity sensor in the bathroom itself is the upgrade here — it reacts within seconds rather than minutes. Swap the entity in both places if you add one.

### Boost while the rangehood runs

Cooking is the biggest single moisture and odour event in most houses, and unlike a shower it comes with an obvious on/off signal already wired into the kitchen. If your hood recirculates rather than ducting outside — as the one in this example does — the ventilation unit is the only thing actually removing that moisture from the house, which makes this the automation to get right.

```yaml
alias: Ventilation - Boost while the rangehood runs
description: Boosts ventilation while the rangehood is on and for 15 minutes after, then returns control to the unit.
mode: restart
triggers:
  - trigger: state
    entity_id: switch.rangehood
    to: "on"
actions:
  - action: fan.set_percentage
    target:
      entity_id: fan.comfoairq
    data:
      percentage: 100
  - wait_for_trigger:
      - trigger: state
        entity_id: switch.rangehood
        to: "off"
    timeout: "02:00:00"
    continue_on_timeout: true
  - delay: "00:15:00"
  - action: fan.set_preset_mode
    target:
      entity_id: fan.comfoairq
    data:
      preset_mode: auto
```

The 15 minute run-on is the point of the automation. Steam and cooking smells linger well after the pan comes off the heat, and this clears them without anyone remembering to do anything. The two hour timeout is a safety net, so a rangehood left on all day cannot strand the unit at full speed forever.

**If your rangehood isn't smart.** Most aren't. Two retrofits, in order of preference:

- **A power-monitoring smart plug or in-line energy meter.** Trigger on watts instead of a switch state — swap the two triggers for `numeric_state` on the power sensor, `above: 20` to start and `below: 10` to stop. Thresholds depend on the appliance; watch the sensor while it runs and pick numbers either side of its idle draw.
- **The rangehood light as a proxy.** Crude, but most people put the light on when they start cooking. Trigger on the light entity instead. Expect false positives when someone just wants the light.

### Why this one matters with a recirculating hood

The hood in this example is a **recirculating** type — grease filter, carbon filter, air blown back into the kitchen. No duct to outside. That is increasingly the default in apartments and airtight new builds, and it changes what the automation is for.

A recirculating hood traps grease and takes the edge off odours. **It removes no moisture whatsoever.** Every gram of steam off a boiling pan stays inside the house. The only route out is the MVHR's kitchen extract point.

So this automation is not a refinement. With a recirculating hood it *is* your cooking moisture strategy — the boost is the mechanism that actually removes the water, and the hood is only telling it when to start.

Three things follow from that.

- **The carbon filter fades, and the MVHR picks up the slack.** Carbon saturates and stops adsorbing odour long before it looks dirty. Replace it on the manufacturer's schedule, typically every few months of regular cooking. Note that `sensor.comfoairq_days_to_replace_filter` tracks the *ventilation unit's* filters only — it knows nothing about your hood.
- **No pressure problem to worry about.** Nothing leaves the building, so a recirculating hood cannot depressurise the house or backdraft a flue. The safety note in the next section does not apply to you.
- **Keep an eye on the kitchen extract valve.** The hood catches most airborne grease, but not all of it, and what escapes ends up at the MVHR's kitchen valve. Wipe it when you change the unit's filters.

**One overlap to be aware of.** The humidity boost earlier in this guide will eventually notice cooking too, because that steam reaches the extract air in the end. The rangehood trigger is simply the faster signal — it fires the moment someone starts cooking, rather than after the blended extract sensor has drifted upward. Running both is fine, and the rare case where they collide is a shower during cooking: whichever finishes first hands control back to `auto`, and the other reasserts on its next threshold crossing. Not worth engineering around unless it annoys you.

### If your hood is ducted instead

Most of the above flips, so this is for readers who don't have the setup described here.

A ducted hood is **extract only** and often moves far more air than the ventilation unit does — 400 to 700 m³/h is common, against roughly 235 m³/h on the reference unit at full speed. While it runs it pulls the house negative, and the shortfall is drawn in through whatever gaps exist.

> **Safety — open-flued appliances.** If you have a wood burner, an open fire, or a gas heater or water heater with an open flue, a powerful ducted rangehood can reverse the flue and pull combustion gases, including carbon monoxide, back into the room. This is a property of the rangehood and the building, not of Home Assistant, and no automation in this guide fixes it. If that describes your house, fit a carbon monoxide alarm and speak to a heating engineer about dedicated makeup air. Do not treat a ventilation boost as a substitute.

It is also worth knowing that **boosting a balanced MVHR is not makeup air.** The ComfoAir Q raises supply and extract together, so pushing it to 100% brings in more air but sends out roughly as much. The net pressure effect is small. What the boost buys with a ducted hood is faster clearance of whatever escapes the hood and drifts through the house — useful, but a smaller job than it does in the recirculating case.

**Whichever type you have: never duct a rangehood into the MVHR system.** Cooking grease will coat the heat exchanger and ductwork, and neither is designed to be cleaned of it. The two systems stay separate, which is why the unit's own kitchen extract point is deliberately sited away from the hob.

### Wind down when the house is empty

```yaml
alias: Ventilation - Away when the house is empty
description: Drops to the lowest setting once everyone has left.
mode: single
triggers:
  - trigger: numeric_state
    entity_id: zone.home
    below: 1
    for: "00:10:00"
actions:
  - action: fan.set_percentage
    target:
      entity_id: fan.comfoairq
    data:
      percentage: 33
```

```yaml
alias: Ventilation - Back to auto when someone comes home
description: Hands control back to the unit as soon as anyone arrives.
mode: single
triggers:
  - trigger: numeric_state
    entity_id: zone.home
    above: 0
actions:
  - action: fan.set_preset_mode
    target:
      entity_id: fan.comfoairq
    data:
      preset_mode: auto
```

Both need Home Assistant to know who's home — the companion app on at least one phone with location sharing on. Without that, skip them.

### Summer night purge

Pull cool night air through the house, but only when outside is genuinely cooler than inside.

```yaml
alias: Ventilation - Summer night purge
description: Ventilates hard at night when it is warm indoors and cooler outside.
mode: single
triggers:
  - trigger: time
    at: "22:00:00"
conditions:
  - condition: numeric_state
    entity_id: sensor.comfoairq_inside_temperature
    above: 23
  - condition: numeric_state
    entity_id: sensor.comfoairq_outside_temperature
    below: sensor.comfoairq_inside_temperature
actions:
  - action: fan.set_percentage
    target:
      entity_id: fan.comfoairq
    data:
      percentage: 100
  - delay: "03:00:00"
  - action: fan.set_preset_mode
    target:
      entity_id: fan.comfoairq
    data:
      preset_mode: auto
```

The second condition compares one sensor against another rather than a fixed number. That's what stops it running on a warm night and making things worse.

### Filter reminder

Find your own notify action under **Developer tools → Actions** by typing `notify`.

```yaml
alias: Ventilation - Filters due soon
description: Warns two weeks ahead and adds filters to the shopping list.
mode: single
triggers:
  - trigger: numeric_state
    entity_id: sensor.comfoairq_days_to_replace_filter
    below: 14
actions:
  - action: notify.mobile_app_your_phone
    data:
      title: Ventilation filters
      message: >-
        Filters are due in
        {{ states('sensor.comfoairq_days_to_replace_filter') }} days.
  - action: todo.add_item
    target:
      entity_id: todo.shopping_list
    data:
      item: Zehnder ComfoAir Q filter set
```

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

## 4. A dashboard to see it all

**Add card → Manual**, then paste:

```yaml
type: vertical-stack
cards:
  - type: heading
    heading: Ventilation

  - type: tile
    entity: fan.comfoairq
    features:
      - type: fan-speed

  - type: glance
    columns: 4
    entities:
      - entity: sensor.comfoairq_outside_temperature
        name: Outside
      - entity: sensor.comfoairq_supply_temperature
        name: Supply
      - entity: sensor.comfoairq_inside_temperature
        name: Inside
      - entity: sensor.comfoairq_exhaust_temperature
        name: Exhaust

  - type: entities
    title: Air and humidity
    entities:
      - entity: sensor.comfoairq_supply_airflow
        name: Supply airflow
      - entity: sensor.comfoairq_exhaust_airflow
        name: Extract airflow
      - entity: sensor.comfoairq_inside_humidity
        name: Indoor humidity
      - entity: sensor.comfoairq_bypass_state
        name: Summer bypass open
      - entity: sensor.comfoairq_power_usage
        name: Power draw
      - entity: sensor.comfoairq_days_to_replace_filter
        name: Filters due in

  - type: history-graph
    hours_to_show: 24
    entities:
      - sensor.comfoairq_supply_temperature
      - sensor.comfoairq_outside_temperature
      - sensor.comfoairq_inside_temperature
```

The history graph is the one to keep. The gap between the outside line and the supply line *is* your heat recovery, drawn over time.

### Energy dashboard

`sensor.comfoairq_energy_total` is a proper lifetime energy meter, so the Energy dashboard takes it directly: **Settings → Dashboards → Energy → Individual devices → Add device**.

Add `sensor.comfoairq_preheater_energy_total` as a second device if you want the frost preheater separately. In a cold snap it can dwarf the fans.

---

## 5. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Home Assistant won't start after the edit | YAML indentation — a tab, or wrong number of spaces | Restore the backup, re-copy the block rather than retyping it |
| No `comfoairq` entities at all | Wrong IP, or gateway on a different network segment | Confirm the address, check the LAN C's link light |
| Config check fails naming a resource | Mistyped resource key | See the naming traps table above — six aren't what you'd expect |
| Fan appears but sensors don't | The `sensor:` block was missed, or a second `sensor:` key overwrote the first | Confirm `sensor:` appears exactly once at the far left of the file |
| Worked, then stopped weeks later | The gateway's IP changed | Set a DHCP reservation for the LAN C in your router |
| Drops out when the Zehnder app is opened | The gateway allows a limited number of registered clients | Remove unused device registrations in the Zehnder app, restart Home Assistant *(commonly reported, not tested here)* |
| Fan stuck at one speed | An automation set a percentage and never handed control back | Call `fan.set_preset_mode` with `auto` from **Developer tools → Actions**, then fix the automation |

---

## 6. ComfoConnect Pro — not yet validated

**Nothing in this section has been tested.** Everything above was written against a LAN C. The ComfoConnect Pro is Zehnder's newer gateway, and whether Home Assistant's `comfoconnect` integration talks to it is an open question — not a known yes, not a known no.

If you have a Pro, don't assume the config block above works unchanged. This is a checklist for whoever validates it, to be replaced with findings.

| # | Test | A useful answer |
|---|---|---|
| 1 | Does the existing integration connect at all? | The exact error from **Settings → System → Logs** after pointing the config at the Pro |
| 2 | Local connection, or cloud-only? | Whether the gateway answers on the local network with no internet access |
| 3 | Does pairing behave the same? | Whether a PIN is needed, and whether it registers in the Zehnder app |
| 4 | Do all twenty-one resources populate? | A list of any that stay unavailable — the resource set may differ |
| 5 | Does fan control work? | Whether `fan.set_percentage` and `fan.set_preset_mode` actually move the unit |
| 6 | Does it survive a reboot of both devices? | Whether it reconnects alone or needs a Home Assistant restart |
| 7 | Can the app and Home Assistant coexist? | Whether opening the Zehnder app knocks Home Assistant offline |
| 8 | Anything the Pro exposes that the LAN C doesn't? | Bypass control and away mode are the two worth checking — the biggest gaps on the LAN C |

If the answer to 1 is no, the follow-up is whether a community integration covers the Pro — in which case this becomes a separate route rather than a variation on the config above.

---

## Building the PDF

```
./build-pdf.sh
```

Output lands in `build/`. See the script for what it needs.

---

*Written against a live ComfoConnect LAN C paired to a ComfoAir Q. Entity IDs, resource keys, units and sample values were read from that installation rather than transcribed from documentation. The ComfoConnect Pro section is explicitly untested and marked as such.*

*Not affiliated with or endorsed by Zehnder. Check your unit's warranty terms before changing how it is controlled.*
