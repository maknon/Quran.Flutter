REM '--no-tree-shake-icons' to show Material icons
REM '--web-renderer canvaskit' to make night mode working in web/mobile/ipad. It also solve the issue with svg pixelized in ipad. now it is the default
call flutter build web --no-tree-shake-icons --release

pause