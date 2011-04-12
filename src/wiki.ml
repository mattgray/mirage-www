open Cow
open Printf

(* Date *)

type month = int

let html_of_month m =
  let str = match m with
    | 1  -> "Jan" | 2  -> "Feb" | 3  -> "Mar"
    | 4  -> "Apr" | 5  -> "May" | 6  -> "Jun"
    | 7  -> "Jul" | 8  -> "Aug" | 9  -> "Sep"
    | 10 -> "Oct" | 11 -> "Nov" | 12 -> "Dec"
    | _  -> "???" in
  <:html<$str:str$>>

type date = {
  month : month;
  day   : int;
  year  : int;
  hour  : int;
  min   : int;
} with html

let date (year, month, day, hour, min) =
  { month; day; year; hour; min }

let atom_date d =
  ( d.year, d.month, d.day, d.hour, d.min)

let short_html_of_date d =
  <:html<last modified on $int:d.day$ $html_of_month d.month$ $int:d.year$>>

(* Entry *)

let html_of_author author =
  match author.Atom.uri with
    | None     -> <:html<Last modified by $str:author.Atom.name$>>
    | Some uri -> <:html<Last modified by <a href=$str:uri$>$str:author.Atom.name$</a>&>>

type category = string * string  (* category, subcategory, see list of them below *)

type body = 
 |File of string
 |Html of Html.t

type entry = {
  updated    : date;
  author     : Atom.author;
  subject    : string;
  categories : category list;
  body       : body;
  permalink  : string;
}

let body_of_entry read_file e =
 match e.body with |File x -> read_file x |Html x -> x

(* Convert a wiki record into an Html.t fragment *)
let html_of_entry ?(want_date=true) read_file e =
  let permalink = sprintf "%s/wiki/%s" Config.baseurl e.permalink in
  let body = body_of_entry read_file e in
  let permalink_disqus = sprintf "%s/wiki/%s#disqus_thread" Config.baseurl e.permalink in
  <:html<
    <div class="wiki_entry">
      $if want_date then html_of_date e.updated else []$
      <div class="wiki_entry_heading">
        <div class="wiki_entry_title">
          <a href=$str:permalink$>$str:e.subject$</a>
        </div>
        <div class="wiki_entry_info">
          <i>$html_of_author e.author$</i>
        </div>
     </div>
     <div class="wiki_entry_body">$body$</div>
     <a href=$str:permalink_disqus$>Comments</a>
   </div>
 >>

let html_of_index read_file =
  let body = read_file "index.md" in
  <:html<
    <div class="wiki_entry">
     <div class="wiki_entry_body">$body$</div>
   </div>
 >>
 
let entry_css = <:css<
  .wiki_entry {
    margin-bottom: 20px;

    pre {
      padding-left: 15px;
      border-left: 1px solid #ddd;
      border: 1px solid #ddd;
      background: #eee;
      font-size: 1.2em;
      margin-left: 2em;
      margin-right: 6em;
    }

    .wiki_entry_heading {
      margin-left: 0px;
      margin-bottom: 0px;
    }
    .wiki_entry_title {
      font-size: 1.8em;
      font-weight: bold;
    }
    .wiki_entry_info {
      margin-top: 0px;
      font-size: 1.0em;
    }
    .wiki_entry_body {
      margin-left: 0px;
      margin-top: 3px;
      font-size: 1.1em;
    }
  }
>>

(* Category *)

type num = {
  l1 : string -> int;
  l2 : string -> string -> int;
}

(* XXX: the num_li functions can be optimized *)
let num_of_entries entries =
  let num_l1 l1 =
    List.fold_left (fun a e ->
      List.fold_left (fun a (l1',_) ->
        if l1' = l1 then a+1 else a
      ) 0 e.categories + a
    ) 0 entries in

  let num_l2 l1 l2 =
    List.fold_left (fun a e ->
      List.fold_left (fun a (l1',l2') ->
        if l1'=l1 && l2'=l2 then a+1 else a
      ) 0 e.categories + a
    ) 0 entries in

  {
    l1 = num_l1;
    l2 = num_l2;
  }

(* One categorie on the right column *)
let short_html_of_category num (l1, l2l) =
  let l2h = List.map (fun l2 ->
    match num.l2 l1 l2 with 
      | 0   -> <:html<<div class="wiki_bar_l2">$str:l2$</div>&>>
      | nl2 ->
        let num = <:html<<i>$str:sprintf " (%d)" nl2$</i>&>> in
        let url = sprintf "%s/wiki/tag/%s/%s" Config.baseurl l1 l2 in
        <:html<<div class="wiki_bar_l2"><a href=$str:url$>$str:l2$</a>$num$</div>&>>
  ) l2l in
  let url = sprintf "%s/wiki/tag/%s" Config.baseurl l1 in
  let l1h = match num.l1 l1 with
    | 0   -> <:html<<div class="wiki_bar_l1">$str:l1$</div>&>>
    | nl1 -> <:html<<div class="wiki_bar_l1"><a href=$str:url$>$str:l1$</a></div>&>> in
  <:html<
    $l1h$
    $list:l2h$
  >>

let short_category_css = <:css<
  .wiki_bar_l1 {
    font-size: 1.2em;
    padding-right: 5px;
  }
  .wiki_bar_l2 {
    font-size: 1em;
    margin-left: 1.5em;
  }
>>

(* The full right bar in wiki *)
let short_html_of_categories entries categories =
  let num = num_of_entries entries in
  let url = sprintf "%s/wiki/" Config.baseurl in
  <:html<
    <div class="wiki_bar">
      <div class="wiki_bar_l0"><a href=$str:url$>Index</a></div>
      $list:List.map (short_html_of_category num) categories$
    </div>
 >>

let short_categories_css = <:css<
  .wiki_bar {
    text-align: right;
    border-right: 1px solid #eee;
    padding: 5px;

    .wiki_bar_l0 {
      font-size: 2.0em;
      padding-right: 5px;
    }

    $short_category_css$
  }
>>

(* Index pages *)

let permalink e =
  sprintf "%s/wiki/%s" Config.baseurl e.permalink

let html_of_category entries (l1, l2) =
  let equal (ll1, ll2) = match l2 with
    | None    -> ll1=l1
    | Some l2 -> ll1=l1 && ll2=l2 in
  let l2_str = match l2 with
    | None    -> ""
    | Some l2 -> "/ " ^ l2 in
  let entries = List.filter (fun e -> List.exists equal e.categories) entries in
  let aux e = <:html<<li><a href=$str:permalink e$>$str:e.subject$</a> ($short_html_of_date e.updated$)</li>&>> in
  match entries with
  | []      -> []
  | entries ->
      <:html<
        <div class="category_index">
          <h3>$str:l1$ $str:l2_str$</h3>
          <ul>$list:List.map aux entries$</ul>
        </div>
      >>

let html_of_categories entries categories =
  let categories =
    List.fold_left
      (fun accu (l1, ll2) -> List.map (fun l2 -> l1, Some l2) ll2 @ accu)
      [] categories in
  let categories = List.rev categories in
  <:html<$list:List.map (html_of_category entries) categories$>>

let category_css = <:css<
  .category_index {
    margin-left: 6px;
    font-size: 1em;
    h3 {
      font-size: 1.2em;
    }
  }
>>

(* Main wiki page; disqus comments are for full entry pages *)
let html_of_page ?disqus ~left_column ~right_column =

  (* The disqus comment *)
  let disqus_html permalink = <:html<
    <div class="wiki_entry_comments">
    <div id="disqus_thread"/>
    <script type="text/javascript"> 
      var disqus_identifer = $str:permalink$; 
      (function() { 
        var dsq = document.createElement('script'); dsq.type = 'text/javascript'; dsq.async = true;
         dsq.src = 'http://openmirage.disqus.com/embed.js';
        (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(dsq);
       })()
    </script>
    </div>
  >> in

  let dh = match disqus with
     | Some perm -> disqus_html perm
     | None      -> <:html< >> in

  <:html<
    <div class="left_column_wiki">
      <div class="summary_information">$left_column$</div>
    </div>
    <div class="right_column_wiki">$right_column$</div>
    $dh$
  >>

let page_css = <:css<
  .left_column_wiki {
    float: left;
    width: 840px;
    $entry_css$;
    $category_css$;
  }
  .right_column_wiki {
    float: right;
    width: 100px;
    $short_categories_css$;
  }
  .wiki_entry_comments {
    float: left;
    width: 600px;
    position: relative;
  }
>>

(* Data *)

let anil = {
  Atom.name = "Anil Madhavapeddy";
  uri       = Some "http://anil.recoil.org";
  email     = Some "anil@recoil.org";
}
let thomas = {
  Atom.name = "Thomas Gazagnaire";
  uri       = Some "http://gazagnaire.org";
  email     = Some "thomas@gazagnaire.org";
}

let rights = Some "All rights reserved by the author"

let categories = [
  "overview", [
      "media"; "usage"; "perf"
  ];
  "language", [
      "syntax"; "dyntype"
  ];
  "backend", [
      "unix"; "xen"; "browser"; "arm"; "mips"
  ];
  "network", [
      "ethernet"; "dhcp"; "arp"; "tcpip"; "dns"; "http";
  ];
  "storage", [
      "block"; "orm";
  ];
  "concurrency", [
      "threads"; "processes"
  ];
]

let entries = [

  { updated    = date (2011, 04, 12, 10, 0);
    author     = anil;
    subject    = "DNS Performance Tests";
    body       = Html Perf.dns;
    permalink  = "performance";
    categories = ["overview","perf"];
  };

  { updated    = date (2011, 04, 12, 9, 0);
    author     = anil;
    subject    = "Papers and Related Work";
    body       = Html Paper.html;
    permalink  = "papers";
    categories = ["overview","media"];
  };

  { updated    = date (2011, 04, 12, 10, 0);
    author     = anil;
    subject    = "Tech Talks";
    body       = File "talks.md";
    permalink  = "talks";
    categories = ["overview","media"];
  };

  { updated    = date (2010, 12, 13, 15, 0);
    author     = thomas;
    subject    = "COW: OCaml on the Web";
    body       = File "cow.md";
    permalink  = "cow";
    categories = ["language","syntax"];
  };
  { updated    = date (2011, 04, 11, 18, 10);
    author     = anil;
    subject    = "Developing the Mirage networking stack on UNIX";
    body       = File "net-unix.md";
    permalink  = "running-ethernet-stack-on-unix";
    categories = ["overview","usage"; "backend","unix"];
  };

  { updated    = date (2011, 04, 11, 11, 0);
    author     = anil;
    subject    = "Source code layout";
    body       = File "repo-layout.md";
    permalink  = "source-code-layout";
    categories = ["overview","usage"];
  };
  { 
    updated    = date (2010, 11, 4, 16, 30);
    author     = thomas;
    subject    = "Introduction to HTCaML";
    categories = ["language","syntax"];
    body       = File "htcaml.md";
    permalink  = "htcaml";
  };
]

let num = num_of_entries entries

let cmp_ent a b = Atom.compare (atom_date a.updated) (atom_date b.updated)

let entries = List.rev (List.sort cmp_ent entries)
let _ = List.iter (fun x -> Printf.printf "ENT: %s\n%!" x.subject) entries

let permalink_exists x = List.exists (fun e -> e.permalink = x) entries

let atom_entry_of_ent filefn e =
  let meta = {
    Atom.id      = permalink e;
    title        = e.subject;
    subtitle     = None;
    author       = Some e.author;
    updated      = atom_date e.updated;
    rights;
  } in {
    Atom.entry = meta;
    summary    = None;
    content    = body_of_entry filefn e;
  }
  
let atom_feed filefn es = 
  let es = List.rev (List.sort cmp_ent es) in
  let updated = atom_date (List.hd es).updated in
  let id = sprintf "%s/wiki/" Config.baseurl in
  let title = "openmirage wiki" in
  let subtitle = Some "a cloud operating system" in
  let feed = { Atom.id; title; subtitle; author=None; rights; updated } in
  let entries = List.map (atom_entry_of_ent filefn) es in
  { Atom.feed=feed; entries }
