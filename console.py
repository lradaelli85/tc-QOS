#!/usr/bin/env python3
# -*- coding: utf-8 -*-.


import curses
from shutil import get_terminal_size
#curses.key
#from curses import panel
#from time import sleep
#from curses.textpad import Textbox, rectangle

class console:
    def __init__(self):
        self.lines = get_terminal_size().lines
        self.cols = get_terminal_size().columns
        self.header_lines = 5
        self.header_columns = self.cols
        self.header_start_line = 0
        self.header_start_col = 0
        self.body_lines = self.lines - 10
        self.body_columns = self.cols
        self.body_start_line = 5
        self.body_start_col = 0
        self.footer_lines = 5
        self.footer_columns = self.cols
        self.footer_start_line = self.lines - 5
        self.footer_start_col = 0


        #pass
    def draw_div(self,lines,cols,start_line,start_col,box=True):
        win = curses.newwin(lines,cols,start_line,start_col)
        if box:
            win.box()
        win.refresh()
        return win


    def add_options(self,win,options,line_start,col_start,direction,step):
        #direction could be only horizontal,vertical
        if type(options) == list:
            for element in options:
                win.addstr(line_start,col_start,element)
                if direction == 'horizontal':
                    col_start += len(element) + step
                elif direction == 'vertical':
                    line_start += step
            win.refresh()

# def move_cursor(n):
#     position = 0
#     items = ['1' , '2' , '3']
#     position += n
#     if position < 0:
#         position = 0
#     elif position >= len(items):
#         position = len(items) - 1


    def menu(self):
        stdscr = curses.initscr()
        #stdscr.clear()
        #stdscr = curses.initscr()
        stdscr.refresh()
        t_lines = self.lines
        t_cols = self.cols
        header = self.draw_div(self.header_lines,self.header_columns,self.header_start_line,self.header_start_col)
        body = self.draw_div(self.body_lines,self.body_columns,self.body_start_line,self.body_start_col)
        footer = self.draw_div(self.footer_lines,self.footer_columns,self.footer_start_line,self.footer_start_col)
        stdscr.move(t_lines -3 ,2)
        cursor_y, cursor_x = stdscr.getyx()
        self.add_options(footer,['Edit' , 'Back'],2,2,'horizontal',2)
        self.add_options(body,['Edit' , 'Back' , 'Add'],2,2,'vertical',5)
        #stdscr.getch()
        #stdscr.refresh()
        stdscr.getkey()
        #k=0
        # while (k != ord('q')):
        #     if k == curses.KEY_RIGHT:






    # if key == curses.KEY_LEFT:
    #         navigate(-1)
    # elif key == curses.KEY_RIGHT:
    #         navigate(1)
    #         curses.A_REVERSE
    # else:
    #if key == curses.KEY_UP:
    #    footer.addstr(2,10, 'aaaa')
    #stdscr.refresh()
    #panel.update_panels()
    #curses.doupdate()

    #stdscr.getkey()



if __name__ == "__main__":
    #screen = console()
    curses.wrapper(console().menu())
