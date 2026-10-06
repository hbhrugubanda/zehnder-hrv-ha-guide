# Zehnder ComfoAir Q + Home Assistant

**A guide to connecting a Zehnder ComfoAir Q MVHR to Home Assistant, and what you can do with it**

Repository: <https://github.com/hbhrugubanda/zehnder-hrv-ha-guide>

---

## Assumptions

- A **Zehnder ComfoAir Q** (Q350 / Q450 / Q600), installed and running.
- A **[ComfoConnect LAN C](#1a-the-comfoconnect-lan-c)** or **[ComfoConnect Pro](#1b-the-comfoconnect-pro)** - a small device that connects to your network.
- A running **Home Assistant** on your network.

If the Zehnder app can see your unit, you have everything you need. This guide covers only the Home Assistant side.

**Relevant sections depend on your installation.** Read **1a** and **2a** for a LAN C, **1b** and **2b** for a Pro. Sections 3 to 5 describe the LAN C; the ideas carry over to a Pro, though it reports a different set of values under different names.

Written against **Home Assistant 2026.9.2**, September 2026. Menu names shift between releases - *Tools* was called *Developer tools* and sat in the sidebar before 2026.2, and *Apps* were *Add-ons* before 2026.6 - so if a path here doesn't match your screen, look for the nearest equivalent under *Settings*.

---

## 1a. The ComfoConnect LAN C

Complete the following before you start:

- **Set a fixed address.** Home Assistant stores the LAN C's IP address, so the address must stay the same. Find it in your router's list of connected devices, then set a **DHCP reservation** for it (some routers call this a **fixed IP address**).

The LAN C has been superseded by the **ComfoConnect Pro**, which has a different setup - see *[section 1b](#1b-the-comfoconnect-pro)*. Home Assistant's built-in integration only communicates with the LAN C.

---

## 1b. The ComfoConnect Pro

The **ComfoConnect Pro** similarly connects your unit to your home network. It has to be set up first. Press the **AP** button, join the temporary **ComfoConnectPro** Wi-Fi network it creates (password on the device label), and open **http://comfoconnectpro.local** in a browser (or **http://10.1.1.1** if that doesn't load). The first visit asks you to set a password for the Pro's settings page; log in with it. From there, connect the Pro to your home network - ethernet or Wi-Fi - and give it a fixed address in your router.

Then, on that same web page, go to **Protocols & Services** and switch the protocol to **Modbus TCP**. Leave the defaults alone: slave ID 1, port 502. Home Assistant can't see the Pro until that is set.

Once that is done, carry on to **section 2b**.

> **Untested.** The rest of this guide was written against a live LAN C. This section comes from Zehnder's own [ComfoConnect PRO installer manual](https://zehnder.lv/wp-content/uploads/2024/12/ComfoConnect-PRO-Installer-manual.pdf), which documents the setup and the full Modbus interface.

---

## 2a. Connect a LAN C to Home Assistant

An integration called **[Zehnder ComfoAir Q](https://www.home-assistant.io/integrations/comfoconnect/)** ships with Home Assistant, so there is nothing to install.

**Take a backup first** - *Settings → System → Backups*. You are about to edit the file Home Assistant reads on startup, so a backup will help if something goes wrong.

Now open `configuration.yaml` and add the block below to the bottom of it. Change the IP to your LAN C's. The easiest way in is the **File editor** app under *Settings → Apps*.

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

1. **Settings → Tools → YAML → Check configuration.** Fix anything it flags - the error identifies the line.
2. **Settings → System →** power icon → **Restart Home Assistant.**
3. **Settings → Tools → States**, filter for `comfoairq`. You should see one `fan.comfoairq` and 21 sensors with live numbers.

Those are your **entities**; each has an **entity ID** like `sensor.comfoairq_inside_temperature`, and you use that ID in automations and dashboards.

Things to watch:

- If `sensor:` already exists at the far left of your file, don't add a second one. Move just the `- platform: comfoconnect` part underneath the existing `sensor:` line.
- `name: ComfoAirQ` decides what every entity is called.
- Any later change to this block needs a full **restart** to take effect.
- If the values stop updating, **restart** Home Assistant. The integration can lose its connection to the LAN C without recovering on its own, and restarting is the only way to reconnect it.

---

## 2b. Connect a Pro to Home Assistant

A Pro speaks **Modbus**. Use either of the following:

- **[Zehnder ComfoConnect Pro](https://github.com/hstrohmaier/ha_comfoconnectpro)**, a community integration listed in HACS. It asks for a name, the Pro's address, the slave ID and the port from section 1b.
  1. If you don't have HACS yet, [download it](https://hacs.xyz/docs/use/download/download/) and [set it up](https://hacs.xyz/docs/use/configuration/basic/) first.
  2. Open the integration in HACS with [this link](https://my.home-assistant.io/redirect/hacs_repository/?owner=hstrohmaier&repository=ha_comfoconnectpro&category=integration), or search HACS for *Zehnder ComfoConnect Pro* ([using the HACS dashboard](https://hacs.xyz/docs/use/repositories/dashboard/)).
  3. Download it and restart Home Assistant.
  4. Add it under *Settings → Devices & Services → Add integration*, searching for *Zehnder ComfoConnect PRO*.
- **Home Assistant's own Modbus integration**, which is built in and needs nothing downloaded. More setting up - you list the values you want yourself, in `configuration.yaml`.
  - The [Modbus integration documentation](https://www.home-assistant.io/integrations/modbus/) shows how to write the `modbus:` block.
  - [Zehnder's register list](https://zehnder.lv/wp-content/uploads/2024/12/ComfoConnect-PRO-Installer-manual.pdf#page=21), pages 21-22 of the installer manual, shows which register holds which value.
  - Zehnder's list numbers registers from 1, and the manual notes that Modbus addresses start at 0, so register 1 is `address: 0` in your configuration.
  - New to `configuration.yaml`? Home Assistant's [configuration guide](https://www.home-assistant.io/docs/configuration/) covers where it lives and how to edit it.

Either way you end up with the unit as entities in Home Assistant and can then incorporate them into automations and dashboards.

The two devices offer different features. The Pro adds away mode, a timed boost, a temperature target and error clearing, and reports CO₂ per zone where sensors are fitted. It does not report fan speed, fan duty, power or energy.

---

## 3. What you get

*Written for the LAN C. A Pro exposes a different set.*

### The control

`fan.comfoairq` is the unit itself. It has four speeds:

| Setting | Percentage |
|---|---|
| Away | `0` |
| Low | `33` |
| Medium | `66` |
| High | `100` |

Setting a percentage puts the unit into **manual** mode and leaves it there. Setting the preset back to `auto` hands control back to the unit's own schedule. `auto` is the only preset available.

### The four air streams

One naming quirk to know first: Zehnder's manuals call the air pulled out of your rooms **extract** air, while Home Assistant calls it **inside** and keeps **exhaust** for the air leaving the building.

| Stream | Meaning | Temperature | Humidity | Live |
|---|---|---|---|---|
| **Outside** | Fresh air arriving from outdoors | `sensor.comfoairq_outside_temperature` | `sensor.comfoairq_outside_humidity` | 12.7 °C · 85% |
| **Supply** | Warmed fresh air blown into your rooms | `sensor.comfoairq_supply_temperature` | `sensor.comfoairq_supply_humidity` | 18.3 °C · 62% |
| **Inside** | Stale air pulled out of kitchen and bathrooms | `sensor.comfoairq_inside_temperature` | `sensor.comfoairq_inside_humidity` | 18.8 °C · 59% |
| **Exhaust** | Spent air leaving the building, heat removed | `sensor.comfoairq_exhaust_temperature` | `sensor.comfoairq_exhaust_humidity` | 13.8 °C · 79% |

> Read those together. Outside air arrived at 12.7 °C and reached the rooms at 18.3 °C. Inside air left the rooms at 18.8 °C and exited the building at 13.8 °C.

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
| `sensor.comfoairq_current_rmot` | Running mean outdoor temperature - a rolling average the unit uses to decide the season has changed | °C |
| `sensor.comfoairq_power_usage` | Current electricity draw | W |
| `sensor.comfoairq_energy_total` | Lifetime electricity used | kWh |
| `sensor.comfoairq_preheater_power_usage` | Frost preheater draw, zero unless genuinely cold | W |
| `sensor.comfoairq_preheater_energy_total` | Lifetime preheater electricity | kWh |

### What it can't do

The integration is read-mostly. Plan around these limits:

- **The bypass is read-only.** You can see how far it's open, not move it.
- **No away or holiday switch.** Closest equivalent is setting the fan to 0%.
- **No filter reset.** Still done at the wall controller or in the Zehnder app.
- **No comfort profiles or temperature targets.** Those stay on the unit.
- **One preset only** - `auto`.

---

## 4. Automation ideas

Here are a list of automation ideas. Each is a trigger and one or two actions, built under **Settings → Automations & Scenes → Create automation** with the visual editor - no YAML needed. Two kinds of entity do most of the work:

- **`fan.comfoairq`** - the unit itself. Either *set percentage* (33 Low, 66 Medium, 100 High) or *set preset mode* back to `auto`.
- **`sensor.comfoairq_*`** - the numbers you trigger on.

> **Note:** Setting a percentage takes the unit out of automatic mode and leaves it there. Every boost must finish by setting the preset back to `auto`.

### Boost when the air gets humid

Start with this one. It needs no extra hardware, since it runs off the unit's own extract humidity sensor.

**When** `sensor.comfoairq_inside_humidity` stays above 70% for five minutes → **run** the fan at 100% → **wait** until it drops back below 63%, giving up after an hour → **set preset to `auto`**. You can adjust the thresholds as required.

**Picking your numbers.** That sensor measures the air being pulled out of your wet rooms, so it rises whenever anyone showers, cooks or dries laundry - one trigger covering the whole house. But it is a blend of every extract point, so it moves more slowly and less sharply than a sensor sitting in the bathroom itself. You could also use a humidity sensor in the bathroom itself instead of the extract sensor.

### Boost while the rangehood runs

This is mostly useful if your kitchen rangehood recirculates. A recirculating hood filters grease and some odour, then blows the air straight back into the room - the smells never leave the house. Boosting the unit while the hood runs gives them somewhere to go if the HRV extract is close by. Whether that is worth automating depends on your kitchen.

**When** the rangehood switches on → **run** the fan at 100% → **wait** until it switches off, giving up after two hours → **wait** a further 15 minutes → **set preset to `auto`**.

**You can work out if your rangehood is on** with a power-monitoring smart plug instead: boost when its power sensor goes above roughly 20 W and release below 10 W, adjusted to whatever the hood actually draws.

### Wind down when the house is empty

This one takes two automations.

**When** the number of people in `zone.home` drops below 1 for ten minutes → **run** the fan at 33%.

**When** it rises above 0 → **set preset to `auto`**.

Both need Home Assistant to know who's home - the companion app on at least one phone with location sharing on.

### Summer night purge

Pull cool night air through the house, but only when outside is genuinely cooler than inside.

**At** 22:00, **if** `sensor.comfoairq_inside_temperature` is above 23 °C **and** `sensor.comfoairq_outside_temperature` is below the inside temperature → **run** the fan at 100% for three hours → **set preset to `auto`**.

That second condition compares one sensor against another, since Home Assistant accepts an entity in place of a value. It is what stops the automation running on a warm night and making things worse.

### Filter reminder

**When** `sensor.comfoairq_days_to_replace_filter` drops below 14 → **send** yourself a notification and **add** a filter set to the shopping list.

Find your own notification action under **Settings → Tools → Actions** by typing `notify` - the name depends on which phone has the companion app installed.

### Further ideas, sketched

Things the sensors support that are worth building once the basics work:

- **CO₂ boost** - if you own an air quality sensor, boost on CO₂ rather than humidity.
- **Quiet overnight** - drop to Low at bedtime, back to `auto` in the morning. Worth it if the unit is audible in a bedroom.
- **Pollen or poor air quality outside** - drop to Low when an outdoor air quality sensor spikes.
- **Bypass watch** - you can't control the bypass, but you can chart `bypass_state` against indoor and outdoor temperature to see whether the unit is doing its job.
- **Efficiency tracking** - a template sensor comparing supply, outside and inside temperatures gives you a live heat recovery percentage to trend over months.
- **Watch the filters age** - chart filter days against `supply_fan_duty`; a clogging filter shows up as rising fan duty for the same airflow.

---

*Written against a live ComfoConnect LAN C paired to a ComfoAir Q. Entity IDs, resource keys, units and sample values were read from that installation. The ComfoConnect Pro section is drawn from Zehnder's published installer manual, and is untested.*

*Not affiliated with or endorsed by Zehnder. Check your unit's warranty terms before changing how it is controlled.*
