LV2 Plumbing
============

A small set of plugins for routing audio and MIDI data, intended to be used
with Ardour3's linear processor chain.

Install
-------

```bash
  git clone https://github.com/x42/plumbing.lv2
  cd plumbing.lv2
  make

  # deploy with either
  make install LV2DIR=$HOME/.lv2
  # or
  sudo make install PREFIX=/usr
```
