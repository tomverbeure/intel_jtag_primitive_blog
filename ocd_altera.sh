
/opt/openocd/bin/openocd -f interface/altera-usb-blaster2.cfg -c "jtag newtap max10 fpga_tap -expected-id 0x031050dd -irlen 10"

