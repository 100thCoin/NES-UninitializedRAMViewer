# Uninitialized RAM Viewer  
This is a pair of ROMs for the Nintento Entertainment System designed to print the uninitialzied values of RAM and VRAM. You can press Left and Right on the controller to determine what page of RAM is being displayed.  
CPURAMViewer never writes to CPU RAM, even avoiding writes to the stack.  
PPURAMViewer copies PPU RAM to CPU RAM, then runs the same code as CPURAMViewer.  

It not not recommended you run this with an everdrive N8 pro, as that cartridge initializes RAM at power on before jumping to the code for the ROM you want to run.

Example screenshot:
<img width="1328" height="930" alt="PageZeroRAM" src="https://github.com/user-attachments/assets/21297a7f-d529-44f6-be67-f7a1e32127a6" />
