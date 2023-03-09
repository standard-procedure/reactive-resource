# ReactiveResource

Add fully reactive, self-contained, views into your Rails apps, using the power of Hotwire.

## The inspiration

I was looking at Svelte and Sveltekit and I was blown away how simple they were. Especially the way Sveltekit divides the work so cleanly between server-side and client-side. And I thought Rails, especially if you add in ViewComponents, has all the pieces for this. They just don't fit together correctly.

Then I discovered Stimulus-Reflex (and ViewComponentReflex). They are so close to what I was after.

But there are two things I wasn't so happy with.

- I love how vue.js, and Svelte, keep everything to do with a component in a single file. Sveltekit separates stuff out, but Svelte is to Sveltekit what ViewComponent is to Rails.

- Stimulus-Reflex adds a whole load of extra infrastructure on top of the stuff I was already using with Hotwire. This makes sense, it looks like Stimulus-Reflex predates Hotwire (or at least the public release of Hotwire). But I don't want to add more stuff in - I want less.

## Usage

When building your Rails app, you divide each page into components. Each component represents a "thing" in your system - either directly - like a User or a Person or an Order. Or indirectly; a menu is a representation of the permissions that a User has.

In Svelte, as the user interacts with the component, actions they perform trigger state changes internally. And those state changes get automatically rendered, with minimal disruption or reloading, onto the page.

So when you add a ReactiveResource::Component to a page, it uses a Stimulus.js controller in the background, that responds to the user's actions and triggers a refresh of the component as needed.

However it's not just the user that can make changes to things on-screen. Suppose you're on a social app and you're looking at someone's profile. Whilst you're looking at it, on the other side of the world, they change their photo. A ReactiveResource::Component will automatically update with their new avatar, without requiring a refresh.

A ReactiveResource is reactive in both directions - from the user to the model and from the model to the user.

There are some important constraints when using ReactiveResource.

Firstly, each component is tied to a single resource - probably an ActiveRecord model.

Secondly, ReactiveResource doesn't do any permissions checking - if you have rendered it onto the page for this user, we assume that this user has permission to see it.

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
    recently_poked_by?(user) ? false : true
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

The button is where it starts to get interesting, and if you've written any Stimulus JS, you'll recognise it. We define a Stimulus event handler, called `perform` and pass it a parameter of `poke`.

ReactiveResource's internal `reactive` Stimulus controller receives the button click, sends it over the network back to our server, and it reaches our PersonCard's `poke` action. The person in question gets poked and the PersonCard on our browser page gets magically redrawn - this time with the "Poke me" button gone, because our user no longer has permission to poke. Of course, we have to rate limit our pokes, we're not savages you know.

While our user is still on this same page, the person represented by the card, decides to update their name - maybe from "Susan" to "Suzie". Again, as the update happens, our user's PersonCard representation automagically updates itself with the new first name.

How does this happen?

As you can probably tell, it's just Hotwire - turbo-frames, turbo-streams and web-sockets.

When a `ReactiveResource::Component` is rendered onto the page, it opens a turbo-stream and wraps the template in a turbo-frame. And then it attaches the `reactive` stimulus controller to itself. The stimulus controller calls back into the server, via a (Rails) ReactiveResourcesController, to register itself and let ReactiveResource know that it is interested in this particular Person. When the component is disconnected from the page, the PersonCard is automatically deregistered by the stimulus controller and the turbo-stream closed.

This means that when Susan updates her name, the Person class, being a `ReactiveResource::Model`, automatically tells ReactiveResource that it has been updated. ReactiveResource knows which ReactiveResource::Components are interested in this Person - including our PersonCard - and generates a turbo-stream broadcast. In standard turbo-rails, this broadcast just renders a partial - so it knows nothing of who the current user is, nor any re-rendering the PersonCard component. Unlike the standard Rails turbo-stream `broadcast` and `broadcast_update_later`, ReactiveResource knows exactly which component needs the update - and therefore it can ensure that the correct Person, correct User and any other ancillary state variables are included during the rendering process.

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
