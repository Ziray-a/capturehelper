# Error Guide and Install Help
This is a small guide that logs the error that I have encountered while trying to
Update the capturehelper to 29.1.3 including tests and compilation.
This might even help you even if you are not using this repo


## Errors you might run into

```diff
- unresolved external symbol PyCFunction_Type
```
You might have either an outdated version of Python or the OBS cmake cant find your libraries, if that is the case make sure you add the Python include directory and the python3.lib from the obs-build-dependency folder to the cmake 
If you dont have it make sure you get it via the 
<a href="https://github.com/obsproject/obs-deps/releases"> obs-deps releases </a> 
##

> I cant change the name of the Binary executable

Obs tends to put their name everywhere in case 