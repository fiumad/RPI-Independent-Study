# RPIce - Custom Silicon Wristwatch
Tasked with finding an interesting project for our independent study at RPI this semester, our group of five students got together and brainstormed ideas, looking for an interesting way to make use of Efabless services and their chipIgnite shuttle. We landed on RPIce, a custom silicon wristwatch that displays the time on rings of LEDs and showcases our custom IC chip directly on its watchface.


### Watchface
![image](https://user-images.githubusercontent.com/81405199/208322717-46b2031a-a138-4a82-8347-cdfb4306e7e2.png)

In the image above, the ring of red LEDs represents hours, green represents minutes, and blue represents seconds. The rows of LEDs in the center represent the minutes and seconds in between the five minute and five second incremented positions included in the rings.

### Block Diagram

![image](https://user-images.githubusercontent.com/81405199/222811044-9bbea220-341e-4e35-b10d-c9ae0c99d604.png)


The design includes two buttons, one to change the mode the watch is currently in (changing secs, changing mins, etc.) and one to increment the target time division that was selected by the mode button. The time is kept in three 12-bit wide shift registers (corresponding to the rings) and two 4-bit wide shift registers (corresponding to the rows in the center). This data is then translated to a format usable by an led matrix which allows us to use less outputs. 

### The Team

This project was made by a group of five students participating in an independent study at Rensselaer Polytechnic Institute in Troy, NY. 

Their names are:

Dan Fiumara - dancarlfiumara@gmail.com

Nico Altomare - altomn@rpi.edu

Gavin Divincent - diving@rpi.edu

Abdul Muizz - muizza@rpi.edu

Hayden Fuller - fulleh@rpi.edu

### Thank You
We would like to thank Efabless for their help and collaboration on this project, as well as NYDesign for providing us with resources and funding to access Efabless services. Thank you!
