# MPAQT


# Docker
$ docker run -it --entrypoint /bin/bash -v /Users/maposto/MPAQT:/MPAQT -v /Users/maposto/reference:/reference  mapostolides/mpaqt_test4

# Singularity

$ singularity shell -B /home -B /tmp -B /project/6007998/maposto/reference -B /project/6007998/maposto/PROJECTS/MPAQT_FINAL/MPAQT /project/6007998/maposto/MODULES/MPAQT.V2.simg


