# mts-converter

## Fast start

For call 
```bash
bulk_video_converter.bash -c config.yaml ~/Videos/input/00001.MTS
```

with `config.yaml` like this
```yaml
ffmpeg:
  bin: /usr/bin/ffmpeg
  threads: 0
  start: 00:00:10
  stop: 00:00:30
profile:
  base:
    # you can mark profile as abstract
    # and it will be used only for inheritance.
    abstract: 1
    output_dir_name: ./out
    pass_log_dir_name: ./pass_log

  my_profile:
    # Other options are inherited from `base`
    extends:   base
    passes: 2
    video:
      preset: veryslow
      width:   1280
      height:  720
      bitrate: 2000k
      codec:
        name : h264
        weightp: 2
        bframes: 3
        opts: "keyint=96:min-keyint=96:no-scenecut"
        profile: high
        level: 3.1
    audio:
      codec:
        name: aac
      channels: 5.1
      bitrate: 320k
```

It generates output log like this:
```yaml
bulk_video_converter.bash:
# NOTICE 29:  bulk_video_converter.bash creates directory /tmp/bulk_video_converter.bash/lMbW6uid
  /home/w495/Videos/input/00001.MTS :
  # /home/w495/Videos/input/00001.MTS  done
  /home/w495/Videos/input/00001.MTS my_profile:
    profile my_profile:
      global input:
          -ss '00:00:10'   -threads '0' 
      # global input done
      video:
         -preset 'veryslow'  -b:v '2000k'  -vf 'scale=1280:720'  -codec:v 'libx264' -profile:v 'high'  -level:v '3.1'  -weightp '2'  -bf '3'  -x264opts 'keyint=96:min-keyint=96:no-scenecut' 
      # video done
      audio:
         -b:a '320k' -ac '6' -strict 'experimental' -codec:a 'aac' 
      # audio done
      global output:
          -ss '00:00:10'   -to '00:00:30' 
      # global output done
      passes:
      # NOTICE 289:  bulk_video_converter.bash creates directory /var/log/bulk_video_converter.bash/2016-05-02_04-09-08-036081777
        pass 1: /usr/bin/ffmpeg -ss '00:00:10' -threads '0' -i '/home/w495/Videos/input/00001.MTS' -preset 'veryslow' -b:v '2000k' -vf 'scale=1280:720' -codec:v 'libx264' -profile:v 'high' -level:v '3.1' -weightp '2' -bf '3' -x264opts 'keyint=96:min-keyint=96:no-scenecut' -pass 1 -passlogfile ./pass_log/00001-my_profile.mts -b:a '320k' -ac '6' -strict 'experimental' -codec:a 'aac' -ss '00:00:10' -to '00:00:30' -f 'mp4' -y '/dev/null' 2>&1 | tee /var/log/bulk_video_converter.bash/2016-05-02_04-09-08-036081777/00001-my_profile-1-mp4.ffmpeg.log 1>&2;
        # pass 1 done
        pass 2: /usr/bin/ffmpeg -ss '00:00:10' -threads '0' -i '/home/w495/Videos/input/00001.MTS' -preset 'veryslow' -b:v '2000k' -vf 'scale=1280:720' -codec:v 'libx264' -profile:v 'high' -level:v '3.1' -weightp '2' -bf '3' -x264opts 'keyint=96:min-keyint=96:no-scenecut' -pass 2 -passlogfile ./pass_log/00001-my_profile.mts -b:a '320k' -ac '6' -strict 'experimental' -codec:a 'aac' -ss '00:00:10' -to '00:00:30' -f 'mp4' -y './out/00001-my_profile.mp4' 2>&1 | tee /var/log/bulk_video_converter.bash/2016-05-02_04-09-08-036081777/00001-my_profile-2-mp4.ffmpeg.log 1>&2;
        # pass 2 done
      # passes done
    # profile my_profile done
  # /home/w495/Videos/input/00001.MTS my_profile done
# NOTICE 325:  bulk_video_converter.bash deletes directory /tmp/bulk_video_converter.bash
# bulk_video_converter.bash done

```

And perform 2 sequential commands for `ffmpeg`.

* For the first pass:
```bash
/usr/bin/ffmpeg                                             \
    -ss '00:00:10'                                          \
    -threads '0'                                            \
    -i '~/Videos/input/00001.MTS'                           \
    -preset 'veryslow'                                      \
    -b:v '2000k'                                            \
    -vf 'scale=1280:720'                                    \
    -codec:v 'libx264'                                      \
    -profile:v 'high'                                       \
    -level:v '3.1'                                          \
    -weightp '2'                                            \
    -bf '3'                                                 \
    -x264opts 'keyint=96:min-keyint=96:no-scenecut'         \
    -pass '1'                                               \
    -passlogfile './pass_log/00001-my_profile.mts'          \
    -b:a '320k'                                             \
    -ac '6'                                                 \
    -strict 'experimental'                                  \ 
    -codec:a 'aac'                                          \
    -ss '00:00:10'                                          \
    -to '00:00:30'                                          \
    -f 'mp4'                                                \
    -y '/dev/null';
```

* And for second one:

```bash
/usr/bin/ffmpeg                                             \
    -ss '00:00:10'                                          \
    -threads '0'                                            \
    -i '~/Videos/input/00001.MTS'                           \
    -preset 'veryslow'                                      \
    -b:v '2000k'                                            \
    -vf 'scale=1280:720'                                    \
    -codec:v 'libx264'                                      \
    -profile:v 'high'                                       \
    -level:v '3.1'                                          \
    -weightp '2'                                            \
    -bf '3'                                                 \
    -x264opts 'keyint=96:min-keyint=96:no-scenecut'         \
    -pass '2'                                               \
    -passlogfile './pass_log/00001-my_profile.mts'          \
    -b:a '320k'                                             \
    -ac '6'                                                 \
    -strict 'experimental'                                  \ 
    -codec:a 'aac'                                          \
    -ss '00:00:10'                                          \
    -to '00:00:30'                                          \
    -f 'mp4'                                                \
    -y './out/00001-my_profile.mp4';
```

