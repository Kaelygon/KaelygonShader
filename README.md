# Unity HLSL shader for VRChat

## Description

I wanted to create a somewhat lightweight placeholder shader for my avatars that I share.
The shader includes features that I most commonly use such as:
	-Alpha cutout with optional mask
	-Normal map with strength slider
	-Emission map with color adjust
	-Cube reflections with strength slider, mask. Interpolated between multiplicative and additive
	-Attenuation mixed with shadow ramp
	-Sh9, four-light, directional light with shadow receive and casting
	-HSV adjustments
	-Shadow color can be changed

### Dependencies

* VRChat SDK : https://vrchat.com/home/download

### Installing

* Import VRChat SDK in a Unity project and extract KaelygonShader files anywhere in the project

### Notes

* Examples are located in KaelygonShader/KaelExamples/KaelygonShaderExample.unity
* Make sure that shadow ramp textures are clamped. Otherwise Attenuation at 0 and 1 will be wrong

## Bugs

	-Four point light shadows are not received
	-Light color mixing may be inaccurate

## Version History

* 26May23
    * Initial Release

## License

Attribution 4.0 International (CC BY 4.0) 

## Acknowledgments

* [catlikecoding] https://catlikecoding.com/unity/tutorials/

## Examples
![alt text](https://i.imgur.com/b0jDPNp.png)
![alt text](https://i.imgur.com/Ni6bY6y.png)