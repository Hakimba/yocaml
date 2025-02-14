open Yocaml

let destination = "_build"
let css_destination = into destination "css"
let images_destination = into destination "images"
let track_binary_update = Build.watch Sys.argv.(0)
let domain = "https://xhtmlboi.com"
let feed_link = into domain "feed.xml"

let rss_channel items () =
  Rss.Channel.make
    ~title:"My superb website"
    ~link:domain
    ~feed_link
    ~description:"Yo"
    items
;;

let may_process_markdown file =
  let open Build in
  if with_extension "md" file
  then Yocaml_markdown.content_to_html ()
  else arrow Fun.id
;;

let pages =
  process_files
    [ "pages/" ]
    (fun f -> with_extension "html" f || with_extension "md" f)
    (fun file ->
      let fname = basename file |> into destination in
      let target = replace_extension fname "html" in
      let open Build in
      create_file
        target
        (track_binary_update
        >>> Yocaml_yaml.read_file_with_metadata (module Metadata.Page) file
        >>> may_process_markdown file
        >>> Yocaml_jingoo.apply_as_template
              (module Metadata.Page)
              "templates/layout.html"
        >>^ Stdlib.snd))
;;

let article_destination file =
  let fname = basename file |> into "articles" in
  replace_extension fname "html"
;;

let articles =
  process_files [ "articles/" ] (with_extension "md") (fun file ->
      let open Build in
      let target = article_destination file |> into destination in
      create_file
        target
        (track_binary_update
        >>> Yocaml_yaml.read_file_with_metadata (module Metadata.Article) file
        >>> Yocaml_markdown.content_to_html ()
        >>> Yocaml_jingoo.apply_as_template
              (module Metadata.Article)
              "templates/article.html"
        >>> Yocaml_jingoo.apply_as_template
              (module Metadata.Article)
              "templates/layout.html"
        >>^ Stdlib.snd))
;;

let css =
  process_files [ "css/" ] (with_extension "css") (fun file ->
      Build.copy_file file ~into:css_destination)
;;

let images =
  let open Preface.Predicate in
  process_files
    [ "../04_first_blog/images" ]
    (with_extension "svg" || with_extension "png" || with_extension "gif")
    (fun file -> Build.copy_file file ~into:images_destination)
;;

let collect_articles_for_index =
  let open Build in
  collection
    (read_child_files "articles/" (with_extension "md"))
    (fun source ->
      track_binary_update
      >>> Yocaml_yaml.read_metadata (module Metadata.Article) source
      >>^ fun x -> x, article_destination source)
    (fun x (meta, content) ->
      x
      |> Metadata.Articles.make
           ?title:(Metadata.Page.title meta)
           ?description:(Metadata.Page.description meta)
      |> Metadata.Articles.sort_articles_by_date
      |> fun x -> x, content)
;;

let rss_feed =
  let open Build in
  collection
    (read_child_files "articles/" (with_extension "md"))
    (fun source ->
      track_binary_update
      >>> Yocaml_yaml.read_metadata (module Metadata.Article) source
      >>^ Metadata.Article.to_rss_item
            (into domain $ article_destination source))
    rss_channel
;;

let index =
  let open Build in
  let* articles = collect_articles_for_index in
  create_file
    (into destination "index.html")
    (track_binary_update
    >>> Yocaml_yaml.read_file_with_metadata (module Metadata.Page) "index.md"
    >>> Yocaml_markdown.content_to_html ()
    >>> articles
    >>> Yocaml_jingoo.apply_as_template
          (module Metadata.Articles)
          "templates/list.html"
    >>> Yocaml_jingoo.apply_as_template
          (module Metadata.Articles)
          "templates/layout.html"
    >>^ Stdlib.snd)
;;

let feed =
  let open Build in
  let* rss = rss_feed in
  create_file
    (into destination "feed.xml")
    (track_binary_update >>> rss >>^ Rss.Channel.to_rss)
;;

let () =
  Logs.set_level ~all:true (Some Logs.Debug);
  Logs.set_reporter (Logs_fmt.reporter ())
;;

let () =
  Yocaml_unix.execute (pages >> css >> images >> articles >> index >> feed)
;;
