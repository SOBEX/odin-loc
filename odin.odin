package loc

import "core:fmt"
import "core:strings"

count_odin::proc(file:^File,contents:string){
   when LOC_DEBUG{
      fmt.printfln("Counting %s",file.path)
      line:=1
      column:=1
      last_count:Count
   }
   in_line_comment:=false
   in_block_comment:=0
   in_single_string:=false
   in_double_string:=false
   in_raw_string:=false
   prev_was_slash:=false
   prev_was_star:=false
   prev_was_escape:=false
   has_code:=false
   has_comment:=false
   for c in contents{
      if in_line_comment{
         if c=='\n'{
            if has_code{
               file.code+=1
            }else if has_comment{
               file.comment+=1
            }else{
               file.blank+=1
            }
            has_code=false
            has_comment=false
            in_line_comment=false
            when LOC_DEBUG do fmt.printfln("exiting line comment at %d,%d",line,column)
         }else if !strings.is_space(c){
            has_comment=true
         }
      }else if in_block_comment>0{
         if c=='\n'{
            if has_code{
               file.code+=1
            }else if has_comment{
               file.comment+=1
            }else{
               file.blank+=1
            }
            has_code=false
            has_comment=false
            prev_was_slash=false
            prev_was_star=false
         }else if c=='*'{
            if prev_was_slash{
               in_block_comment+=1
               prev_was_slash=false
               when LOC_DEBUG do fmt.printfln("entering block comment #%d at %d,%d",in_block_comment,line,column)
            }else{
               prev_was_star=true
            }
         }else if c=='/'{
            if prev_was_star{
               in_block_comment-=1
               when LOC_DEBUG do fmt.printfln("exiting block comment #%d at %d,%d",in_block_comment+1,line,column)
               prev_was_star=false
            }else{
               prev_was_slash=true
            }
         }else if !strings.is_space(c){
            has_comment=true
            prev_was_slash=false
            prev_was_star=false
         }else{
            prev_was_slash=false
            prev_was_star=false
         }
      }else if in_single_string{
         if c=='\n'{
            file.code+=1
            has_code=false
            has_comment=false
            in_single_string=false
            when LOC_DEBUG do fmt.printfln("exiting unterminated single string at %d,%d",line,column)
            prev_was_escape=false
         }else if c=='\\'{
            if prev_was_escape{
               has_code=true
               prev_was_escape=false
            }else{
               prev_was_escape=true
            }
         }else if c=='\''{
            if prev_was_escape{
               has_code=true
               prev_was_escape=false
            }else{
               has_code=true
               in_single_string=false
               when LOC_DEBUG do fmt.printfln("exiting single string at %d,%d",line,column)
            }
         }else{
            has_code=true
            prev_was_escape=false
         }
      }else if in_double_string{
         if c=='\n'{
            file.code+=1
            has_code=false
            has_comment=false
            in_double_string=false
            when LOC_DEBUG do fmt.printfln("exiting unterminated double string at %d,%d",line,column)
            prev_was_escape=false
         }else if c=='\\'{
            if prev_was_escape{
               has_code=true
               prev_was_escape=false
            }else{
               prev_was_escape=true
            }
         }else if c=='"'{
            if prev_was_escape{
               has_code=true
               prev_was_escape=false
            }else{
               has_code=true
               in_double_string=false
               when LOC_DEBUG do fmt.printfln("exiting double string at %d,%d",line,column)
            }
         }else{
            has_code=true
            prev_was_escape=false
         }
      }else if in_raw_string{
         if c=='\n'{
            file.code+=1
            has_code=true
            has_comment=false
         }else if c=='`'{
            has_code=true
            in_raw_string=false
            when LOC_DEBUG do fmt.printfln("exiting raw string at %d,%d",line,column)
         }
      }else{
         if c=='\n'{
            if has_code{
               file.code+=1
            }else if has_comment{
               file.comment+=1
            }else{
               file.blank+=1
            }
            has_code=false
            has_comment=false
            prev_was_slash=false
         }else if c=='/'{
            if prev_was_slash{
               in_line_comment=true
               when LOC_DEBUG do fmt.printfln("entering line comment at %d,%d",line,column)
               prev_was_slash=false
            }else{
               prev_was_slash=true
            }
         }else if c=='*'{
            if prev_was_slash{
               in_block_comment+=1
               when LOC_DEBUG do fmt.printfln("entering block comment #%d at %d,%d",in_block_comment,line,column)
               prev_was_slash=false
            }else{
               has_code=true
            }
         }else if c=='\''{
            has_code=true
            in_single_string=true
            when LOC_DEBUG do fmt.printfln("entering single string at %d,%d",line,column)
            prev_was_slash=false
         }else if c=='"'{
            has_code=true
            in_double_string=true
            when LOC_DEBUG do fmt.printfln("entering double string at %d,%d",line,column)
            prev_was_slash=false
         }else if c=='`'{
            has_code=true
            in_raw_string=true
            when LOC_DEBUG do fmt.printfln("entering raw string at %d,%d",line,column)
            prev_was_slash=false
         }else if !strings.is_space(c){
            has_code=true
            prev_was_slash=false
         }else if prev_was_slash{
            has_code=true
            prev_was_slash=false
         }
      }
      when LOC_DEBUG{
         if c=='\n'{
            if file.code!=last_count.code{
               fmt.printfln("code line %d (%d -> %d)",line,last_count.code,file.code)
            }
            if file.comment!=last_count.comment{
               fmt.printfln("comment line %d (%d -> %d)",line,last_count.comment,file.comment)
            }
            if file.blank!=last_count.blank{
               fmt.printfln("blank line %d (%d -> %d)",line,last_count.blank,file.blank)
            }
            last_count=file.count
            line+=1
            column=1
         }else{
            column+=1
         }
      }
   }
   if has_code{
      file.code+=1
      when LOC_DEBUG do fmt.printfln("code line %d (%d -> %d)",line,last_count.code,file.code)
   }else if has_comment{
      file.comment+=1
      when LOC_DEBUG do fmt.printfln("comment line %d (%d -> %d)",line,last_count.comment,file.comment)
   }else{
      when LOC_DEBUG do fmt.printfln("ignored blank line %d (%d -> %d)",line,last_count.blank,file.blank)
   }
}

_::/*/**/*`
*/`
`
