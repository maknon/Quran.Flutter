$env:Path += ';E:\Support\git\bin\'
(Get-ChildItem -Path "E:/Quran Media/pages/hafs-mobile-svg" -Recurse -ErrorAction SilentlyContinue -Force) | Foreach-Object -Parallel {
	$basename = $_.BaseName
	E:/Support/flutter/bin/dart.bat run vector_graphics_compiler -i "E:/Quran Media/pages/hafs-mobile-svg/$basename.svg" -o ./hafs/$basename.svg.vec
}
