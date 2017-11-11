# useful-code
Code I've written that I might find useful again later. Or more realistically, I'll look back at this code and scoff.

Some of these I want to Gemify since I use these in multiple projects

- ~~[ ] SqlQuerier/Skillet~~ HAH! Turns out `.as_json` on an AR query does this already. And does it WAY better (even returns correct array intead of SQL array when doing `ARRAYAGG()`). HAH again! Maybe not always better since it serializes things like dates which takes a lot of time and memory for very large datasets (i.e. User.all.as_json). So there is still a chance!
- [ ] TokenService
- [ ] ActionCache
