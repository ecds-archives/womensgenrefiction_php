<?php 

include "taminoConnection.class.php";
include "existConnection.class.php";

class xmlDbConnection {

  // connection parameters
  var $host;
  var $port;
  var $db;
  var $coll;
  var $dbtype; 	// tamino,exist
  // whether or not to display debugging information
  var $debug;
  
  // these variables used internally
  var $xmldb;	// tamino or exist class object
  var $xsl_result;

  // xml/xpath variables - references
  var $xml;
  var $xpath;

  // variables for return codes/messages?

  // cursor variables (needed here?)
  var $cursor;
  var $count;
  var $position;

  // variables for highlighting search terms
  var $begin_hi;
  var $end_hi;


  function xmlDbConnection($argArray) {
    $this->host = $argArray['host'];
    $this->db = $argArray['db'];
    $this->coll = $argArray['coll'];
    $this->debug = $argArray['debug'];

    $this->dbtype = $argArray['dbtype'];
    if ($this->dbtype == "exist") {
      // create an exist object, pass on parameters
      $this->xmldb = new existConnection($argArray);
    } else {	// for backwards compatibility, make tamino default
      // create a tamino object, pass on parameters
     $this->xmldb = new taminoConnection($argArray);
    }

    // xmlDb count is the same as tamino or exist count 
    $this->count =& $this->xmldb->count;
    // xpath just points to tamino xpath object
    $this->xml =& $this->xmldb->xml;
    $this->xpath =& $this->xmldb->xpath;

    // variables for highlighting search terms
    // begin highlighting variables are now defined when needed, according to number of terms
    $this->end_hi = "</span>";
  }

  // send an xquery & get xml result
  function xquery ($query, $position = NULL, $maxdisplay = NULL) {
    // pass along xquery & parameters to specified xml db
    $this->xmldb->xquery($this->encode_xquery($query), $position, $maxdisplay);
  }

  // x-query : should only be in tamino...
  function xql ($query, $position = NULL, $maxdisplay = NULL) {
    // pass along xql & parameters to specified xml db
    $this->xmldb->xql($this->encode_xquery($query), $position, $maxdisplay);
  }

  // retrieve cursor, total count    (xquery cursor by default)
  function getCursor () {
    $this->xmldb->getCursor();
  }
  // get x-query cursor (for backwards compatibility)
  function getXqlCursor () {
    $this->xmldb->getXqlCursor();
  }

   // transform the database returned xml with a specified stylesheet
   function xslTransform ($xsl_file, $xsl_params = NULL) {
     /* load xsl & xml as DOM documents */
     $xsl = new DomDocument();
     $xsl->load("xsl/$xsl_file");

     /* create processor & import stylesheet */
     $proc = new XsltProcessor();
     $xsl = $proc->importStylesheet($xsl);
     if ($xsl_params) {
       foreach ($xsl_params as $name => $val) {
         $proc->setParameter(null, $name, $val);
       }
     }
     /* transform the xml document and store the result */
     $this->xsl_result = $proc->transformToDoc($this->xmldb->xml);
   }

   // transform the created xsl result  with a specified stylesheet
   function xslTransformResult ($xsl_file, $xsl_params = NULL) {
     /* load xsl & xml as DOM documents */
     $xsl = new DomDocument();
     $xsl->load("xsl/$xsl_file");

     /* create processor & import stylesheet */
     $proc = new XsltProcessor();
     $xsl = $proc->importStylesheet($xsl);
     if ($xsl_params) {
       foreach ($xsl_params as $name => $val) {
         $proc->setParameter(null, $name, $val);
       }
     }
     /* transform the xsl result, and replace it with the result */
     $this->xsl_result = $proc->transformToDoc($this->xsl_result);
   }

   function printResult ($term = NULL) {
     if ($this->xsl_result) {
       if (isset($term[0])) {
         $this->highlightXML($term);
         // this is a bit of a hack: the <span> tags used for
         // highlighting are strings, and not structural xml; this
         // allows them to display properly, rather than with &gt; and
         // &lt; entities
         print html_entity_decode($this->xsl_result->saveXML());
       } else {
         print $this->xsl_result->saveXML();
       }
     }

   }

   // create <span> tags for highlighting based on number of terms
   function defineHighlight ($num) {
     $this->begin_hi = array();
    // strings for highlighting search terms 
    for ($i = 0; $i < $num; $i++) {
      $this->begin_hi[$i]  = "<span class='term" . ($i + 1) . "'>";
    }
   }


   // get the content of an xml node by name when the path is unknown
   function findNode ($name, $node = NULL) {
     // this function is for backwards compatibility... 
     if (isset($this->xpath)) {     // only use the xpath object if it has been defined
       $n = $this->xpath->query("//$name");
       // return only the value of the first one
       if ($n) { $rval = $n->item(0)->textContent; }
     } else {
       $rval =0;
     }
     return $rval;
   }



   // Highlight the search strings within the xsl transformed result.
   // Takes an array of terms to highlight.
   function highlightString ($str, $term) {
     // note: need to fix regexps: * -> \w* (any word character)
      // FIXME: how best to deal with wild cards?

     // only do highlighting if the term is defined
     for ($i = 0; (isset($term[$i]) && ($term[$i] != '')); $i++) {
       // replace tamino wildcard (*) with regexp -- 1 or more word characters 
       $_term = str_replace("*", "\w+", $term[$i]);
     // Note: regexp is constructed to avoid matching/highlighting the terms in a url 
       $str = preg_replace("/([^=|']\b)($_term)(\b)/i",
	      "$1" . $this->begin_hi[$i] . "$2$this->end_hi$3", $str);
       // special case when term is at the beginning of string
       $str = preg_replace("/(^)($_term)(\b)/i",
        "$1" . $this->begin_hi[$i] . "$2$this->end_hi$3", $str);

     }
     return $str;
   }

   // highlight text in the xml structure
   function highlightXML ($term) {
     // if span terms are not defined, define them now
     if (!(isset($this->begin_hi))) { $this->defineHighlight(count($term)); }
     $this->highlight_node($this->xsl_result, $term);
   }

   // recursive function to highlight search terms in xml text
   function highlight_node ($n, $term) {
     $children = $n->childNodes;
     foreach ($children as $c) {
       if ($c instanceof domElement) {
	 $this->highlight_node($c, $term);
       } else if ($c instanceof DOMCharacterData) {
	 $c->nodeValue = $this->highlightString($c->nodeValue, $term);
       }
     }
   }
   
   // print out search terms, with highlighting matching that in the text
   function highlightInfo ($term) {
     // if span terms are not defined, define them 
     if (!(isset($this->begin_hi))) { $this->defineHighlight(count($term)); }
     if (isset($term[0])) {
       print "<p align='center'>The following search terms have been highlighted: ";
       for ($i = 0; isset($term[$i]); $i++) {
	 print "&nbsp; " . $this->begin_hi[$i] . "$term[$i]$this->end_hi &nbsp;";
       }
       print "</p>";
     }
   }

   // print out links to different result sets, based on cursor
   // arguments: url to link to (pos & max # to display will be added), max
   function resultLinks ($url, $position, $max) {
     //FIXME: at least in exist, we can get a default maximum from result set itself...
     $result = "<div class='resultlink'>";
	if ($this->count > $max) {
	  $result .= "<li class='firstresultlink'>More results:</li";
	  for ($i = 1; $i <= $this->count; $i += $max) {
	    if ($i == 1) {
	      $result .= '<li class="firstresultlink">';
	    } else { 
	      $result .= '<li class="resultlink">';
	    }
            // url should be based on current search url, with new position defined
	    $myurl = $url .  "&pos=$i&max=$max";
            if ($i != $position) {
	      $result .= "<a href='$myurl'>";
	    }
    	    $j = min($this->count, ($i + $max - 1));
    	    // special case-- last set only has one result
    	    if ($i == $j) {
      	      $result .= "$i";
    	    } else {
      	      $result .= "$i - $j";
    	    }
	    if ($i != $position) {
      	      $result .= "</a>";
    	    }
    	    $result .= "</li>";
	  }
	}
	$result .= "</div>"; 
	return $result;
   }


  // convert a readable xquery into a clean url for tamino or exist
  function encode_xquery ($string) {
    // get rid of multiple white spaces
    $string = preg_replace("/\s+/", " ", $string);
    // convert spaces to their hex equivalent
    $string = str_replace(" ", "%20", $string);
    // convert ampersand & # within xquery (e.g., for unicode entities) to hex
    $string = str_replace("&", "%26", $string);
    $string = str_replace("#", "%23", $string);
    return $string;
  }

   // print out xml (for debugging purposes)
   function displayXML ($transformed = 0) {
     if ($transformed) { 	// display xml resulting from xsl transformation
       if ($this->xsl_result) {
         $this->xsl_result->formatOutput = true;
         print "<pre>";
         print htmlentities($this->xsl_result->saveXML());
         print "</pre>";
       }
     } else {			// by default, display xml returned by query
       if ($this->xml) {
         $this->xml->formatOutput = true;
         print "<pre>";
         print htmlentities($this->xml->saveXML());
         print "</pre>";
       }
     }
   }


}
