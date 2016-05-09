
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