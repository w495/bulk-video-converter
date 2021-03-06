# 0.1505870726

1. Add simple tests to `./examples/assay` folder.
2. Make default config more pleasant.
3. Make test framework more predictable: add sort to test search.
4. Add test numbering to test framework.

# 0.1505859356

1. Add `travis` support.
2. Fix tests and configuration due to `travis` requirements.


# 0.1505573195

1. Add tests based on examples.
2. Split examples to `complex`, `featured` and `experiments`.
3. Fix compatibility errors.
4. Fix some minor issues.

# 0.1470294456

1.  Add switching of audio and video and their codecs.
2.  Add `qq` filename handling.
3.  Add support of ffmpeg video filters.
4.  Add support of scene detection filter
    (`-filter:v "select='gt(scene,0.4)'"` ).
4. Add special support of `showinfo` filter,
    (`-filter:v "select='gt(scene,0.4),showinfo'"` ),
5. Add log handling with callbacks.
6. Add minimal set of callbacks.

# 0.1463888719 

1. Add ffmpeg-log to config and to command line arguments.
2. Fix `error handling` issues (trap signals and trap ERR).
3. Reverse this file.

# 0.1463867480

Add `is_async` and `no_async` mode to config handling.
In this way you can handle your files and profiles 
in consecutive way. Just add `no_async` or `no_async_files` 
or `no_async_profiles` to `self` section of the config.
For example:
```YAML
self:
  no_async: true 
  # no_async_files: true # only for files
  # no_async_profiles: true # only for profiles
```
Also you can use `--no-async*` command line arguments.
Default is asynchronous handling for files and profiles both.

# 0.1463347060

1.  Add multiple templates for `depends`.
2.  Add YAML-based handling for h264 and h265 options.
3.  Add some new codec options (for h264).
4.  Add permanent `yadif=1:-1:0` video filter. 
    You can to switch it off with setting `prorgressive: null` 
    for `your_profile/video/prorgressive`.

# 0.1462762887

Add `depends` logic.

While all profiles are handled in parallel way, sometimes it is 
necessary when one profile depends on results of other one. 
If p1 needs to use the results of p0, it should wait for results of p0.
In this case you should use `depends` key in the profile.
For p0 and p1, this would be looks like 

```YAML
p0: ...
p1: 
    depends: p0

```







