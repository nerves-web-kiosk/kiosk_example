# KioskExample

This is the example kiosk application for followings,

- [kiosk_nerves_rpi4](https://github.com/nerves-web-kiosk/kiosk_system_rpi4)
- [kiosk_nerves_rpi5](https://github.com/nerves-web-kiosk/kiosk_system_rpi5)

## How to try

```sh
git clone https://github.com/nerves-web-kiosk/kiosk_example.git
cd kiosk_example
export MIX_TARGET=rpi4
mix deps.get
mix firmware
mix burn
```

Then,

1. Insert SD to your rpi4
1. Connect micro HDMI cable to your rpi4 and display
1. Boot it!!

You will see Phoenix LiveDashboard on your display!!!

You can change the URL to use `KioskExample.change_url("http://example.com")`
on IEx console over SSH.

And there are some functions in `KioskExample` module which lead browser to famous URL. Enjoy!!
