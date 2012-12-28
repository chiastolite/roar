require 'test_helper'
require 'roar/representer/feature/hypermedia'
require 'roar/representer/json'

class HypermediaTest
  describe "Hypermedia Feature" do


    before do
      @bookmarks = Class.new do
        include AttributesConstructor
        include Roar::Representer::XML
        include Roar::Representer::Feature::Hypermedia

        self.representation_wrap = "bookmarks"
      end

      @bookmarks_with_links = Class.new(@bookmarks)
      @bookmarks_with_links.class_eval do
        self.representation_wrap = "bookmarks"

        property :id
        link :self do "http://bookmarks" end
        link :all do "http://bookmarks/all" end

        attr_accessor :id, :self, :all
      end
    end


    describe "#to_xml" do
      it "sets up links and renders <link> correctly in XML" do
        assert_xml_equal '<bookmarks>
                            <id>1</id>
                            <link rel="self" href="http://bookmarks"/>
                            <link rel="all" href="http://bookmarks/all"/>
                          </bookmarks>', @bookmarks_with_links.new(:id => 1).to_xml
      end

      it "still works even if there are no links defined" do
        assert_xml_equal '<bookmarks/>', @bookmarks.new.to_xml
      end

      it "doesn't render links with :links => false" do
        assert_xml_equal '<bookmarks>
                            <id>1</id>
                          </bookmarks>',
          @bookmarks_with_links.new(:id => 1).to_xml(:links => false)
      end
    end

    describe "#to_json" do
      class Note
        include Roar::Representer::JSON
        include Roar::Representer::Feature::Hypermedia
        link(:self) { "http://me" }
      end

      it "works twice" do
        note = Note.new
        assert_equal note.to_json, note.to_json
      end

      it "sets up links even when nested" do
        class Page
          include AttributesConstructor
          include Roar::Representer::JSON
          property :note, :class => Note
          attr_accessor :note
        end

        assert_equal "{\"note\":{\"links\":[{\"rel\":\"self\",\"href\":\"http://me\"}]}}", Page.new(:note => Note.new).to_json
      end
    end



    describe "#from_xml" do
      it "extracts links from document" do
        doc = @bookmarks_with_links.from_xml(%{
        <bookmarks>
          <link rel="self" href="http://bookmarks">
        </bookmarks>
        })

        assert_kind_of Roar::Representer::Feature::Hypermedia::LinkCollection, doc.links
        assert_equal 1, doc.links.size
        assert_equal(["self", "http://bookmarks"], [doc.links_array.first.rel, doc.links_array.first.href])
      end

      it "sets up an empty link list if no links found in the document" do
        assert_equal [], @bookmarks_with_links.from_xml(%{<bookmarks/>}).links_array
      end
    end


    describe "#links" do
      before do
        @set  = @bookmarks.new
        hyper = Roar::Representer::Feature::Hypermedia::Hyperlink

        @set.links = [
          {:rel => "self", :href => "http://self"},
          {:rel => "next", :href => "http://next"}].collect do |config|
            link = hyper.new
            link.rel  = config[:rel]
            link.href = config[:href]
            link
          end
      end

      describe "#links=" do
        it "wraps links in a LinkCollection" do
          assert_kind_of Roar::Representer::Feature::Hypermedia::LinkCollection, @set.links
          assert_equal 2, @set.links.size
        end
      end

      describe "#link[]" do
        it "returns link object" do
          assert_equal "http://self", @set.links["self"].href
          assert_equal "http://self", @set.links[:self].href
          assert_equal "http://next", @set.links[:next].href
          assert_equal nil, @set.links[:prev]
        end
      end

      it "returns an empty list when no links present" do
        assert_equal Roar::Representer::Feature::Hypermedia::LinkCollection.new, @bookmarks.new.links
      end
    end


    # TODO: remove me.
    describe "#find_links_definition" do
      representer_for do
        property :id
        link :self
      end

      subject { Object.new.extend(rpr) }

      it "returns Definition if links are present" do
        subject.send(:find_links_definition).must_be_kind_of Roar::Representer::Feature::Hypermedia::LinksDefinition
      end
    end
  end
end

class LinksDefinitionTest < MiniTest::Spec
  describe "LinksDefinition" do
    before do
      @d = Roar::Representer::Feature::Hypermedia::LinksDefinition.new(:links)
    end

    it "accepts options in constructor" do
      assert_equal [], @d.rel2block
    end

    it "accepts configuration" do
      @d.rel2block << {:rel => :self}
      assert_equal [{:rel=>:self}], @d.rel2block
    end

    it "responds to #clone" do
      @d.rel2block << {:rel => :self}
      assert @d.clone.rel2block.object_id != @d.rel2block.object_id
    end


    it "responds to #each to iterate rel2block" do
    end

  end
end

class LinkCollectionTest < MiniTest::Spec
  describe "LinkCollection" do
    subject { Roar::Representer::Feature::Hypermedia::LinkCollection.new }
    
    describe "#add" do
      it "keys by using rel string" do
        subject.size.must_equal 0
        subject.add(link = link(:rel => :self))
        subject.values.must_equal [link]
        subject.add(link = link(:rel => "self"))
        subject.values.must_equal [link]
      end
    end
  end
end

class HyperlinkTest < MiniTest::Spec
  Hyperlink = Roar::Representer::Feature::Hypermedia::Hyperlink
  describe "Hyperlink" do
    subject { Hyperlink.new(:rel => "self", "href" => "http://self", "data-whatever" => "Hey, @myabc") }

    it "accepts string keys in constructor" do
      assert_equal "Hey, @myabc", subject.send("data-whatever")
    end

    it "responds to #rel" do
      assert_equal "self", subject.rel
    end

    it "responds to #href" do
      assert_equal "http://self", subject.href
    end

    it "responds to #replace with string keys" do
      @link.replace("rel" => "next")
      assert_equal nil, subject.href
      assert_equal "next", subject.rel
    end

    it "responds to #each and implements Enumerable" do
      assert_equal ["rel:self", "href:http://self", "data-whatever:Hey, @myabc"], subject.collect { |k,v| "#{k}:#{v}" }
    end
  end
end

class HyperlinkInheritanceTest < MiniTest::Spec
  describe "when the base representer has a link" do
    before do
      module BaseRepresenter
        include Roar::Representer::JSON
        include Roar::Representer::Feature::Hypermedia

        link(:base) { "http://base" }
      end

       module Foo
        include Roar::Representer::JSON
        include Roar::Representer::Feature::Hypermedia
        include BaseRepresenter

        link(:foo) { "http://foo" }
      end

       module Bar
        include Roar::Representer::JSON
        include Roar::Representer::Feature::Hypermedia
        include BaseRepresenter

        link(:bar) { "http://bar" }
      end
    end

    it "should inherit parent links" do
      foo = Object.new.extend(Foo)

      assert_equal "{\"links\":[{\"rel\":\"base\",\"href\":\"http://base\"},{\"rel\":\"foo\",\"href\":\"http://foo\"}]}", foo.to_json
    end

  end
end
