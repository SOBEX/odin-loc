package loc

import "core:fmt"
import "core:strings"

Odin_State_Code::struct{
   prev_was_slash:bool
}

Odin_State_Line_Comment::struct{
}

Odin_State_Block_Comment::struct{
   depth:int,
   prev_was_slash:bool,
   prev_was_star:bool
}

Odin_State_Single_String::struct{
   prev_was_escape:bool
}

Odin_State_Double_String::struct{
   prev_was_escape:bool
}

Odin_State_Raw_String::struct{
}

Odin_State::struct{
   has_code:bool,
   has_comment:bool,
   substate:union #no_nil{
      Odin_State_Code,
      Odin_State_Line_Comment,
      Odin_State_Block_Comment,
      Odin_State_Single_String,
      Odin_State_Double_String,
      Odin_State_Raw_String
   }
}

odin_count::proc(file:^File,contents:string){
   when LOC_DEBUG{
      fmt.printfln("Counting %s",file.path)
      last_count:Count
      line:=1
      column:=1
   }
   state:Odin_State
   for c in contents{
      switch &substate in state.substate{
      case Odin_State_Code:
         switch c{
         case '\n':
            if state.has_code||substate.prev_was_slash{
               file.code+=1
            }else if state.has_comment{
               file.comment+=1
            }else{
               file.blank+=1
            }
            state.has_code=false
            state.has_comment=false
            substate.prev_was_slash=false
         case '/':
            if substate.prev_was_slash{
               state.substate=Odin_State_Line_Comment{}
               when LOC_DEBUG do fmt.printfln("entering line comment at %d,%d",line,column)
            }else{
               substate.prev_was_slash=true
            }
         case '*':
            if substate.prev_was_slash{
               state.substate=Odin_State_Block_Comment{depth=1}
               when LOC_DEBUG do fmt.printfln("entering block comment #%d at %d,%d",1,line,column)
            }else{
               state.has_code=true
            }
         case '\'':
            state.has_code=true
            state.substate=Odin_State_Single_String{}
            when LOC_DEBUG do fmt.printfln("entering single string at %d,%d",line,column)
         case '"':
            state.has_code=true
            state.substate=Odin_State_Double_String{}
            when LOC_DEBUG do fmt.printfln("entering double string at %d,%d",line,column)
         case '`':
            state.has_code=true
            state.substate=Odin_State_Raw_String{}
            when LOC_DEBUG do fmt.printfln("entering raw string at %d,%d",line,column)
         case:
            if !strings.is_space(c)||substate.prev_was_slash{
               state.has_code=true
            }
            substate.prev_was_slash=false
         }
      case Odin_State_Line_Comment:
         switch c{
         case '\n':
            if state.has_code{
               file.code+=1
            }else if state.has_comment{
               file.comment+=1
            }else{
               file.blank+=1
            }
            state.has_code=false
            state.has_comment=false
            state.substate=Odin_State_Code{}
            when LOC_DEBUG do fmt.printfln("exiting line comment at %d,%d",line,column)
         case:
            if !strings.is_space(c){
               state.has_comment=true
            }
         }
      case Odin_State_Block_Comment:
         switch c{
         case '\n':
            if state.has_code{
               file.code+=1
            }else if state.has_comment||substate.prev_was_slash||substate.prev_was_star{
               file.comment+=1
            }else{
               file.blank+=1
            }
            state.has_code=false
            state.has_comment=false
            substate.prev_was_slash=false
            substate.prev_was_star=false
         case '/':
            if substate.prev_was_star{
               substate.depth-=1
               when LOC_DEBUG do fmt.printfln("exiting block comment #%d at %d,%d",substate.depth+1,line,column)
               if substate.depth==0{
                  state.substate=Odin_State_Code{}
               }else{
                  substate.prev_was_star=false
               }
            }else if substate.prev_was_slash{
               state.has_comment=true
            }else{
               substate.prev_was_slash=true
            }
         case '*':
            if substate.prev_was_slash{
               substate.depth+=1
               when LOC_DEBUG do fmt.printfln("entering block comment #%d at %d,%d",substate.depth,line,column)
               substate.prev_was_slash=false
            }else if substate.prev_was_star{
               state.has_comment=true
            }else{
               substate.prev_was_star=true
            }
         case:
            if !strings.is_space(c)||substate.prev_was_slash||substate.prev_was_star{
               state.has_comment=true
            }
            substate.prev_was_slash=false
            substate.prev_was_star=false
         }
      case Odin_State_Single_String:
         switch c{
         case '\n':
            file.code+=1
            state.has_code=false
            state.has_comment=false
            state.substate=Odin_State_Code{}
            when LOC_DEBUG do fmt.printfln("exiting unterminated single string at %d,%d",line,column)
         case '\\':
            if substate.prev_was_escape{
               state.has_code=true
               substate.prev_was_escape=false
            }else{
               substate.prev_was_escape=true
            }
         case '\'':
            if substate.prev_was_escape{
               state.has_code=true
               substate.prev_was_escape=false
            }else{
               state.has_code=true
               state.substate=Odin_State_Code{}
               when LOC_DEBUG do fmt.printfln("exiting single string at %d,%d",line,column)
            }
         case:
            state.has_code=true
            substate.prev_was_escape=false
         }
      case Odin_State_Double_String:
         switch c{
         case '\n':
            file.code+=1
            state.has_code=false
            state.has_comment=false
            state.substate=Odin_State_Code{}
            when LOC_DEBUG do fmt.printfln("exiting unterminated double string at %d,%d",line,column)
         case '\\':
            if substate.prev_was_escape{
               state.has_code=true
               substate.prev_was_escape=false
            }else{
               substate.prev_was_escape=true
            }
         case '\"':
            if substate.prev_was_escape{
               state.has_code=true
               substate.prev_was_escape=false
            }else{
               state.has_code=true
               state.substate=Odin_State_Code{}
               when LOC_DEBUG do fmt.printfln("exiting double string at %d,%d",line,column)
            }
         case:
            state.has_code=true
            substate.prev_was_escape=false
         }
      case Odin_State_Raw_String:
         switch c{
         case '\n':
            file.code+=1
            state.has_code=true
            state.has_comment=false
         case '`':
            state.has_code=true
            state.substate=Odin_State_Code{}
            when LOC_DEBUG do fmt.printfln("exiting raw string at %d,%d",line,column)
         case:
            state.has_code=true
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
   switch substate in state.substate{
   case Odin_State_Code:
      if substate.prev_was_slash{
         state.has_code=true
      }
   case Odin_State_Line_Comment:
      ;
   case Odin_State_Block_Comment:
      if substate.prev_was_slash||substate.prev_was_star{
         state.has_comment=true
      }
   case Odin_State_Single_String:
      if substate.prev_was_escape{
         state.has_code=true
      }
   case Odin_State_Double_String:
      if substate.prev_was_escape{
         state.has_code=true
      }
   case Odin_State_Raw_String:
      ;
   }
   if state.has_code{
      file.code+=1
      when LOC_DEBUG do fmt.printfln("code line %d (%d -> %d)",line,last_count.code,file.code)
   }else if state.has_comment{
      file.comment+=1
      when LOC_DEBUG do fmt.printfln("comment line %d (%d -> %d)",line,last_count.comment,file.comment)
   }else{
      when LOC_DEBUG do fmt.printfln("ignored blank line %d (%d -> %d)",line,last_count.blank,file.blank)
   }
}
