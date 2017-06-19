THE NATIVE RENDERING PLUGIN (https://bitbucket.org/vivichrist/cshinunity/)
The plugin is all C++ and requires the following includes/libraries to compile:

	GLEW - on windows this should not be needed as it is statically linked
	OpenGL
	dlib version >= 19.4.0 (scource is provided in the root project directory)
	GLM (header library included in the root project directory)

On linux this should just work. All output is compiled to the build/ directory.
Resulting .dll or .so library should be dragged into Unity:
Assets/Plugins/x86_64 (delete the old plugin first).
Compiling the plugin may not be necessary as there should be a working and up to
date plugin in the Unity Assets/Plugins/x86_64 folder. However the windows
plugin will need to be compiled to replace the existing plugin which also
requires:
	Windows SDK (DirectX includes and libs)
	Visual Studio 2017

UNITY PROJECT (https://github.com/vivichrist/TheClusterShader/)
To make clustering work in the unity project. All materials in the scene
(final.scene) should be changed from the Standard shader to Clustering shader.
For some reason this doen't save and I have no idea why... Selecting the main
camera in hierachy the script Clustering shows the settings, I have set clusters
to a tile size of 64 and depth slices of 16 for quick rendering. Feel free to
tinker. Larger resolutions should have bigger tile sizes to have interactive
frame rates. Keys WASD and mouse look when you press play.

The project can't be built in the Unity editor (Linux beta), again, I don't know
why.
