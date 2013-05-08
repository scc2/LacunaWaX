
All images in ROOT/user/assets.zip will get included in the installer, taking up 
space.  So images related to LacunaWaX that don't need to be included in that 
installer should live here instead.


Metrize_Icons.zip
    - Contains .svg files (among other formats), at 512².

    - They were changed to .png files with
        $ mogrify -format png *.svg

    - HOWEVER, rescaling 512² images down to the size I need them resulted in 
      the images being very pixellated.  So I re-converted to .png with resize 
      with:
        $ mogrify -format png -resize 64x64 *.svg

        - And actually, I didn't do *.svg - I only resized the images I need for 
          the app to keep assets.zip to a reasonable size.

    - Rescaling from 64² to the size I need results in acceptable images.  I 
      could resize them with mogrify to the exact size I need in the app, but I 
      haven't decided 100% what that size will be yet, so a little rescale is OK 
      for now.

onebit icons.zip
    - Downloaded from here: 
      http://www.iconfinder.com/search/?q=iconset%3Aonebit&resettype=1

    - The originals are only 48², but rescaling them in the app results in ugly 
      images.  So I'm resizing them with mogrify before adding them to 
      assets.zip.

