# ReactiveResource

Add fully reactive, self-contained, components into your Rails apps, using the power of Hotwire.

## The inspiration

I was looking at [Svelte](https://svelte.dev) and [Sveltekit](https://kit.svelte.dev) and I was blown away how simple they were. Especially the way Sveltekit divides the work so cleanly between server-side and client-side. And I thought Rails, especially if you add in [ViewComponents](https://viewcomponent.org), has all the pieces for this. They just don't fit together correctly.

Then I discovered [Stimulus-Reflex](https://docs.stimulusreflex.com) (and [ViewComponentReflex](https://github.com/joshleblanc/view_component_reflex)). They are so close to what I was after.

But there are two things I wasn't so happy with.

- I love how Vue, React and Svelte keep everything to do with a component in a single file. The very name "component" implies that everything is self-contained, so I don't want some stuff in the model, some in the view, some in the controller and some in the reflex.

- Stimulus-Reflex adds a whole load of extra infrastructure on top of the stuff I was already using with Hotwire. This makes sense, it looks like Stimulus-Reflex predates Hotwire (or at least the public release of Hotwire). But I don't want to add more stuff in - I want less.

## Usage

When building your Rails app, you divide each page into components. Each component represents a "thing" in your system - either directly - like a User or a Person or an Order. Or indirectly; a menu is a representation of the permissions that a User has.

In Svelte, as the user interacts with the component, actions they perform trigger state changes internally. And those state changes get automatically rendered, with minimal disruption or reloading, onto the page.

So when you add a `ReactiveResource::Component` to a page, it uses a [Stimulus](https://stimulus.hotwired.dev/) controller in the background, that responds to the user's actions and triggers a refresh of the component as needed.

However it's not just the user that can make changes to things on-screen. Suppose you're on a social app and you're looking at someone's profile. Whilst you're looking at it, on the other side of the world, they change their photo. A ReactiveResource::Component will automatically update with their new avatar, without requiring a refresh.

A ReactiveResource is reactive in both directions - from the user to the model and from the model to the user.

There are some important constraints when using ReactiveResource.

Firstly, each component is tied to a _single_ resource - probably an ActiveRecord model.

Secondly, ReactiveResource doesn't do any permissions checking - if you have allowed the component to be rendered onto the page then we assume that this user has permission to see it. Of course, your component can include its own permissions checks as it is being rendered, as the example below shows.

## How this differs from Javascript components

The major difference to the likes of Svelte, React and Vue is that, being Rails, everything is rendered server-side. When your user does something to the component in their browser, it makes a server round-trip, updates the component and then re-renders it. This will always be slower than just working purely client-side. Stimulus-reflex uses a web-socket for this round-trip, which will be significantly faster than ReactiveResource which goes through a Rails controller. But client-side state management is _hard_ so I think the cost is worth it.

## How this differs from Turbo and Hotwire

The biggest issue I have with Turbo is the broadcast mechanism. When a model updates, it can broadcast its changes by rendering a partial, which then gets sent out to everyone who is listening on that particular stream. This is relatively fast and it works great for simple scenarios - but as soon as you have multiple users with complex permissions, it falls short. Models do not know who the current user is, so the partial they render cannot take account of who is allowed to do what. I've ended up broadcasting a "loader" partial, which contains a turbo-frame that then loads the real content from the browser - where we have access to the session and hence the current user. This works, but it's twice as much work - and it ends up in lots of little requests if you're showing a big table with lots of rows that are all changing frequently.

ReactiveResource solves this by making the broadcast a two stage process. The model tells ReactiveResource that it has changed, then ReactiveResource re-renders any components that are interested in this change. As the component only registers its interest after it has been rendered, it knows who the current user is.

This approach may not be as scalable. If a million people are looking at a particular page at the same time, the Turbo approach will result in a million broadcasts of a single partial. But the ReactiveResource approach will result in a million _different_ components - one for each user - being broadcast. However, it will be fine for hundreds, thousands, even tens of thousands of concurrent users, which is good enough for me.

Unlike standard Rails, ReactiveResource is designed to keep each component fully self-contained. One file for the HTML, the CSS and the server-side code. There's no JS (that you need to touch). And therefore no jumping from one file to the other in your editor of choice.

Finally, with pure Hotwire, it's easy to forget to update stuff. You might have, for example, an email inbox which updates as new emails arrive. But if you also have an "unread email count" badge in the footer, plus a "flagged emails" drop-down menu in the header, that's three different partials that you have to remember to broadcast. What if another team member adds another view that's dependent on your inbox model and forgets to add it to the model's broadcast?

With ReactiveResource, each component is tied to a particular model. You can have as many different inboxes, filters, badges and menus as you want. If they declare that they are observing your inbox, every time the inbox updates then all the views will. There's nothing to forget.

## Quick Start

Let's say you're building a retro social network app. As we're harking back to a time before privacy scandals, you want to be able to "poke" your friends, just like it's 2010. So have a Person class that looks something like this:

```ruby
class Person < ApplicationRecord
  include ReactiveResource::Model

  validates :first_name, presence: true
  validates :last_name, presence: true
  has_one_attached :avatar
  has_many :pokes, touch: true, dependent: :destroy

  def has_been_poked_by!(user)
    return unless can_be_poked_by? user
    pokes.create! from: user
  end

  def recently_poked_by?(user)
    pokes.from(user).recent.any?
  end

  def can_be_poked_by?(user)
    !recently_poked_by?(user)
  end
end
```

Our person has a first and last name, an avatar image, and a list of pokes - with a couple of helper methods for figuring out who is allowed to poke and who has been poking.

There are many ways that you will want to represent people in your app, but let's start out by showing them as "cards". So your ReactiveResource will start off something like this:

```ruby
class PersonCard < ReactiveResource::Component
  represents :person

  state :selected, :boolean, redraw: true

  template <<-HTML
    <div <%= classes :card, selected: :selected %>>
      <div <%= classes :details %>>
        <div><%= image_tag person.avatar.url %></div>
        <div>
          <p>First name: <%= person.first_name %></p>
          <p>Last name: <%= person.last_name %></p>
        </div>
      </div>
      <div <%= classes :footer %>>
        <input type="checkbox" <%= bind :checked, :selected %>></input>
        <% if person.can_be_poked_by?(user) %>
          <button <%= react_with :poke %>>Poke me</button>
        <% end %>
      </div>
    </div>
  HTML

  styles <<-CSS
    .card {
      background-color: #eee;
    }
    .card .selected {
      border: 1px solid #A00;
    }
    .card .details {
      display: flex;
      justify-content: space-between;
    }
    .card .footer {
      display: flex;
      justify-content: space-between;
    }
  CSS

  def poke
    person.has_been_poked_by! user
  end

  def toggle_selection
    selection = selection.blank? ? "selected" : nil
  end
end
```

The `PersonCard` firstly states that it represents a person. It defines a template that displays our Person record and, if the user has permission, also shows a "Poke me" button.

The button is where it starts to get interesting. It says it will `react_with` a `poke`. Internally, ReactiveResource uses a Stimulus controller and attaches an event handler that does the work.

ReactiveResource's internal `reactive` Stimulus controller receives the button click, sends it over the network back to our server, and it reaches our PersonCard's `poke` action. The person in question gets poked and the PersonCard on our browser page gets magically redrawn - this time with the "Poke me" button gone (because our user no longer has permission to poke - even in 2010, we have to rate limit our pokes; we're not savages you know).

While our user is still on this same page, the person represented by the card, decides to update their name - maybe from "Susan" to "Suzie". Again, as the update happens, our user's PersonCard representation automagically updates itself with the new first name.

How does this happen?

As you can probably tell, it's just Hotwire - turbo-frames, turbo-streams and web-sockets.

When a `ReactiveResource::Component` is rendered onto the page, it opens a turbo-stream and wraps the template in a turbo-frame. And then it attaches the `reactive` stimulus controller to itself. The stimulus controller calls back into the server, via a (Rails) ReactiveResourcesController, to register itself and let ReactiveResource know that it is interested in this particular Person. When the component is disconnected from the page, the PersonCard is automatically deregistered by the stimulus controller and the turbo-stream closed.

This means that when Susan updates her name, the Person class, being a `ReactiveResource::Model`, automatically tells ReactiveResource that it has been updated. ReactiveResource knows which `ReactiveResource::Components` are interested in this Person - including our PersonCard - and generates a turbo-stream broadcast. In standard turbo-rails, this broadcast just renders a partial - so it knows nothing of who the current user is. But ReactiveResource knows exactly which component needs the update - and therefore it can ensure that the correct Person, correct User and any other ancillary state variables are included during the rendering process.

Likewise, when the user hits the "Poke me" button, the stimulus controller sends the request to the ReactiveResourcesController on the server. It locates the PersonCard, attaching the correct Person, User and any other state - and then calls the `poke` method. The `poke` method creates the Poke record and then, because `touch: true` is set on the `has_many` association, the Person record tells ReactiveResource that it has been updated and yet another turbo-stream broadcast is sent out.

## Do you want to know more?

The [Lifecycle](docs/lifecycle.md) of a ReactiveResource.
[Reacting](docs/actions.md) to the user.
Listening for [events](docs/events.md).
Component [state](docs/component-state.md).
HTML [templates](docs/templates.md).
Styling and [CSS](docs/css.md).
Managing [multiple resources](docs/multiple-resources.md) in one component.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "reactive_resource"
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install reactive_resource
```

## Contributing

Contribution directions go here.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
