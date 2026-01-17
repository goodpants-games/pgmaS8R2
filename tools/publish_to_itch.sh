cd exports
butler push lovejs pumkinhead/unyuland:html5 --if-changed
butler push win-x64 pumkinhead/unyuland:win-x64 --if-changed
butler push unyuland.love pumkinhead/unyuland:love --if-changed
cd ..