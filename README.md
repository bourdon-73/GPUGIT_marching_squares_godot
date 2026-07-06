This was hard. Learning GLSL was not easy but I almost made it work. Im still proud tho.
This is the main article that got me going : https://catlikecoding.com/unity/tutorials/marching-squares-2/



1. We generate point data directly inside glsl using Simplex noise.
<img width="750" height="750" alt="tutorial-image" src="https://github.com/user-attachments/assets/0c85dc9d-30f4-42a6-b745-7f3881bd14e3" />

2.Next we send back the results using buffers which is super fast. And we build a mesh from that data every frame.


the issues : 
- The current problem is that some starting chunks aren't generated
- Some triangle artifacts are created.
