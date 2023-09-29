# Error Guide and Install Help
This is a small guide that logs the error that I have encountered while trying to
Update the capturehelper to 29.1.3 including tests and compilation.
This might even help you even if you are not using this repo


## Errors you might run into

```diff
- unresolved external symbol PyCFunction_Type
```
You might have either an outdated version of Python or the OBS cmake cant find your libraries, if that is the case make sure you add the Python include directory and the python3.lib path from the obs-build-dependency folder to the cmake cli, where they are named ```PYTHON_INCLUDE_DIR``` and ```PYTHON_LIB```
If you dont have it make sure you get it via the 
<a href="https://github.com/obsproject/obs-deps/releases"> obs-deps releases</a>. 
##

> I cant change the name of the Binary executable (Windows)

Obs tends to put their name everywhere, in the Windows case, you need to change the line
```
 set_target_properties(obs PROPERTIES WIN32_EXECUTABLE ON OUTPUT_NAME "obs${_ARCH_SUFFIX}")
```
in ```UI/cmake/legacy.cmake``` to whatever you wish.
##
> I Used the powershell script to install the dependencies but its not working (Windows)

Unfortunately the powershell script, even though referenced in the OBS' Windows custom build guide, installs not all the requerements, here using the <a href="https://github.com/obsproject/obs-deps/releases"> obs-deps releases </a> is you best option.
##
> After Compiling OBS says that libcurl.dll is missing (Windows)

Sometimes Cmake doesnt use the curl that comes with git for Windows (mingw64), what fixed it for me was reinstalling curl in git bash with <a href="https://github.com/Microsoft/vcpkg">vcpkg</a> using ```./vcpkg.exe install curl```
##
>Some Packages could not be found

1. Try setting the Cmake variable CMAKE_PREFIX_PATH to the dependencies of your os if you dont have any dependencies  <a href="https://github.com/obsproject/obs-deps/releases"> install them</a>.
2. It might me that the package is not in your depts, in that case check if the date of your depts coincides with the release date of your build version.
3. Unfortunately you might need to find said dependency by yourself
