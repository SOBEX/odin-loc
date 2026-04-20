package loc

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"
import "core:thread"
import "core:time"

LOC_DEBUG::#config(LOC_DEBUG,ODIN_DEBUG)

Count::struct{
   code:int,
   comment:int,
   blank:int,
}

count_add::#force_inline proc(count:^Count,add:Count){
   count.code+=add.code
   count.comment+=add.comment
   count.blank+=add.blank
}

File::struct{
   path:string,
   name:string,
   extension:string,
   depth:int,
   using count:Count
}

Folder::struct{
   path:string,
   name:string,
   depth:int,
   files_start:int,
   files_end:int,
   folders_start:int,
   folders_end:int
}

Counter::#type proc(file:^File,contents:string)

Extension::struct{
   name:string,
   extension:string,
   counter:Counter
}

@rodata supported_extensions:=[?]Extension{
   {"Odin","odin",odin_count}
}

search_folder::proc(path:string,files:^[dynamic]File,folders:^[dynamic]Folder,depth:int){
   //TODO either handle single file or figure something out
   f,open_err:=os.open(path)
   if open_err!=nil{
      fmt.eprintfln("Error walking %q: %v",path,os.error_string(open_err))
      return
   }
   defer os.close(f)

   it:=os.read_directory_iterator_create(f)
   defer os.read_directory_iterator_destroy(&it)

   for fi in os.read_directory_iterator(&it){
      err_path,err:=os.read_directory_iterator_error(&it)
      if err!=nil{
         fmt.eprintfln("Error walking %q: %v",err_path,os.error_string(err))
         continue
      }

      if fi.type==.Directory{
         files_start:=len(files)
         folders_start:=len(folders)
         search_folder(fi.fullpath,files,folders,depth+1)
         files_end:=len(files)
         folders_end:=len(folders)
         if files_start<files_end{
            path:=strings.clone(fi.fullpath)
            _,name:=os.split_path(path)
            append(folders,Folder{
               path=path,
               name=name,
               depth=depth+1,
               files_start=files_start,
               files_end=files_end,
               folders_start=folders_start,
               folders_end=folders_end,
            })
         }
      }else if fi.type==.Regular{
         _,ext:=os.split_filename(fi.name)
         for supported_extension in supported_extensions{
            if ext==supported_extension.extension{
               path:=strings.clone(fi.fullpath)
               _,name:=os.split_path(path)
               _,extension:=os.split_filename(name)
               append(files,File{
                  path=path,
                  name=name,
                  extension=extension,
                  depth=depth+1
               })
            }
         }
      }
   }

   err_path,err:=os.read_directory_iterator_error(&it)
   if err!=nil{
      fmt.eprintfln("Error walking %q: %v",err_path,os.error_string(err))
   }
}

search::proc(path:string)->(files:[dynamic]File,folders:[dynamic]Folder){
   files_start:=len(files)
   folders_start:=len(folders)
   search_folder(path,&files,&folders,0)
   files_end:=len(files)
   folders_end:=len(folders)
   append(&folders,Folder{
      path=strings.clone(path),
      files_start=files_start,
      files_end=files_end,
      folders_start=folders_start,
      folders_end=folders_end,
   })
   return files,folders
}

count_single::proc(file:^File){
   data,err:=os.read_entire_file_from_path(file.path,context.allocator)
   if err!=nil{
      fmt.eprintln("Error reading %q: %v",file.path,os.error_string(err))
      return
   }
   defer delete(data,context.allocator)
   contents:=string(data)

   for supported_extension in supported_extensions{
      if file.extension==supported_extension.extension{
         supported_extension.counter(file,contents)
         break
      }
   }
}

count_worker::proc(task:thread.Task){
   file:=cast(^File)task.data
   count_single(file)
}

count::proc(files:[]File){
   when LOC_DEBUG{
      for &file in files{
         count_single(&file)
      }
   }else{
      pool:thread.Pool
      thread.pool_init(&pool,context.allocator,min(max(1,os.get_processor_core_count()),len(files)))
      defer thread.pool_destroy(&pool)

      for &file in files{
         thread.pool_add_task(&pool,context.allocator,count_worker,&file)
      }

      thread.pool_start(&pool)
      thread.pool_finish(&pool)
   }
}

INDENT_WIDTH::3

print_file::proc(out:io.Writer,file:File,indent:int){
   if indent!=file.depth{
      fmt.eprintln("Error:",file.depth,"should be",indent,file)
      return
   }

   name:=indent==0?file.path:file.name
   fmt.wprintfln(out,"% 8i % 8i % 8i  % *s",file.code,file.comment,file.blank,len(name)+(indent+1)*INDENT_WIDTH,name)
}

print_folder::proc(out:io.Writer,files:[]File,folders:[]Folder,folder:Folder,indent:int){
   if indent!=folder.depth{
      fmt.eprintln("Error:",folder.depth,"should be",indent,folder)
      return
   }

   count:Count
   for i in folder.files_start..<folder.files_end{
      count_add(&count,files[i].count)
   }
   name:=indent==0?folder.path:folder.name
   fmt.wprintfln(out,"% 8i % 8i % 8i  % *s"+os.Path_Separator_String,count.code,count.comment,count.blank,len(name)+indent*INDENT_WIDTH,name)

   for i in folder.folders_start..<folder.folders_end{
      if folders[i].depth==indent+1{
         print_folder(out,files,folders,folders[i],indent+1)
      }
   }

   for i in folder.files_start..<folder.files_end{
      if files[i].depth==indent+1{
      }
   }
}

print::proc(files:[]File,folders:[]Folder){
   bufout:bufio.Writer
   bufio.writer_init(&bufout,os.to_writer(os.stdout))
   out:=bufio.writer_to_writer(&bufout)
   defer{
      bufio.writer_flush(&bufout)
      bufio.writer_destroy(&bufout)
   }

   fmt.wprintfln(out,"% 8s % 8s % 8s  %s","code","comment","blank","name")
   //TODO either handle single file or figure something out
   print_folder(out,files[:],folders[:],folders[len(folders)-1],0)
}

main::proc(){
   path:="."
   if len(os.args)>=2{
      clean_path,err:=os.clean_path(os.args[1],context.temp_allocator)
      if err!=nil{
         fmt.eprintfln("Error cleaning %q: %v",os.args[1],os.error_string(err))
         return
      }
      path=clean_path
   }

   if !os.exists(path){
      fmt.eprintfln("Error finding %q: %v",path,os.error_string(os.General_Error.Not_Exist))
      return
   }

   if !os.is_absolute_path(path){
      absolute_path,err:=os.get_absolute_path(path,context.temp_allocator)
      if err!=nil{
         fmt.eprintfln("Error getting absolute path of %q: %v",path,os.error_string(err))
         return
      }
      path=absolute_path
   }

   if !os.exists(path){
      fmt.eprintfln("Error finding %q: %v",path,os.error_string(os.General_Error.Not_Exist))
      return
   }

   when LOC_DEBUG do fmt.println("path:",path)

   search_start:=time.tick_now()
   files,folders:=search(path)
   search_end:=time.tick_now()

   defer delete(files)
   defer delete(folders)
   defer for file in files do delete(file.path)
   defer for folder in folders do delete(folder.path)

   when LOC_DEBUG do fmt.println("folders:",folders[:])

   //TODO spin up threads while searching for files? cant use pointers because dynamic may realloc
   count_start:=time.tick_now()
   count(files[:])
   count_end:=time.tick_now()

   when LOC_DEBUG do fmt.println("files:",files[:])

   print_start:=time.tick_now()
   print(files[:],folders[:])
   print_end:=time.tick_now()

   fmt.println("Time to search:",time.tick_diff(search_start,search_end))
   fmt.println("Time to  count:",time.tick_diff(count_start,count_end))
   fmt.println("Time to  print:",time.tick_diff(print_start,print_end))
}
