<tasks>
<task>
Create a python api, based on FastAPI, that can: 
- create 'sessions', stored as a local folder in the project directory (data/)
- add files to the session folder based on actions performed by the end user
- read from that session folder based on requests from the user. 
The python api should allow a user to create: 
- "objects", which have a location in 3d space, a type, and other metadat
- "images", which will typically be camera or screenshots from the browser/xr interface
- "videos", following a similar pattern.
- "audio", following a similar pattern.
</task>
<task>
Create a browswer interface, which can perform the actions that correspond with our python api:
- Add new objects in the field of view
- Take a screenshot of the current buffer/browser window
- Record audio using the native capability
</task>
<task>
Create an XR, augmented reality interface, which allows a user to visualize the elements in actual 3d space, and:
- Allows the user to take a picture with the camera and send it to python
- Allows the user to take a screenshot in much the same way
- Allows a user to record audio
- Allows a user to add new objects to the scene.
Each of these actions should be tied to a button combination on the Meta Oculus Quest 3, the device we will be testing on. 
</task>
</tasks>