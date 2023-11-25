local Layout = require('src.helpers.layout')
local Constants = require('src.constants')
local Map = require('src.entities.map')
local Utils = require('src.helpers.utils')

local Dino = require('src.cards.dino')
local Caveman = require('src.cards.caveman')
-- local Thunder = require('src.cards.thunder')

local Deck = {
	default_scale = 0.2,

	deck_selected = Constants.DECK_SELECTED,

	selectable_cards = 4,

	-- if greather than `selectable_cards`
	queue_next_cards = {},

	-- TODO: should come from DB
	decks = {
		deck1 = {
			Dino,
			Caveman,
		}
	}
}

function Deck:load()
	-- if greather than `selectable_cards`, should rotate cards
	if #self.decks[self.deck_selected] > self.selectable_cards then

		-- get the cards left from deck and make unselectable
		-- and add to queue
		for i = self.selectable_cards + 1, #self.decks[self.deck_selected] do
			self.decks[self.deck_selected][i].selectable = false
			table.insert(self.queue_next_cards, self.decks[self.deck_selected][i])
		end

		self.queue_next_cards[1].preview_card = true
	end
end

function Deck:update(dt)
	self:define_positions()
	self:check_cooldown(dt)
end

function Deck:draw()
	for i = 1, self.selectable_cards do
		local card = self.decks[self.deck_selected][i]

		if card == nil then return end

		if card.selected then
			self:highlight_selected_card(card)
		end

		local mouse_x, mouse_y = love.mouse.getPosition()

		if (
			mouse_x >= card.x and mouse_x <= (card.x + (card.card_img:getWidth() * self.default_scale))
			and mouse_y >= card.y and mouse_y <= (card.y + (card.card_img:getHeight() * self.default_scale))
			and not card.is_card_loading
		) then
			love.graphics.draw(card.card_img, card.x, card.y - 100, 0, self.default_scale, self.default_scale)
			self:draw_cooldown(card.x, card.y - 100, card.cooldown)
		else
			love.graphics.draw(card.card_img, card.x, card.y, 0, self.default_scale, self.default_scale)
			self:draw_cooldown(card.x, card.y, card.cooldown)
		end

		if card.is_card_loading then
			local x = card.x + (card.card_img:getWidth() * self.default_scale) / 2
			local y = card.y + (card.card_img:getHeight() * self.default_scale) / 2

			love.graphics.stencil(function()
				love.graphics.draw(card.card_img, card.x, card.y, 0, self.default_scale, self.default_scale)
			end, "replace", 1, false)

			love.graphics.setColor(1, 0, 0, 0.5)
			love.graphics.setStencilTest('equal', 1)
			love.graphics.arc("fill", x, y, 130, -math.pi / 2, -math.pi / 2 + (2 * math.pi * (card.current_cooldown / card.cooldown)), 100)
			love.graphics.setColor(1, 1, 1)

			love.graphics.setStencilTest()
		end
	end

	if #self.queue_next_cards > 0 then
		self:draw_preview_card()
	end
end

function Deck:define_positions()
	local deck = self.decks[self.deck_selected]

	-- local position = Layout:down_right(196, 206) -- card sizes
	local position = Layout:down_right(Dino.card_img:getWidth() * self.default_scale, (Dino.card_img:getHeight() * self.default_scale) - 150)

	-- assign default positions
	for i = 1, self.selectable_cards do
		local card = deck[i]

		-- for cases when the deck has less than 4 cards
		if card == nil then return end

		card.x = position.width - (i * 200)
		card.y = position.height
	end

	-- default position for preview card
	-- if more than 4 cards, should show the preview card
	if #deck > 4 then
		-- get preview card
		self.queue_next_cards[1].x = position.width
		self.queue_next_cards[1].y = position.height + 35

		self.queue_next_cards[1].preview_card = true
	end
end

-- the next card on queue
function Deck:draw_preview_card()
	love.graphics.draw(self.queue_next_cards[1].card_img, self.queue_next_cards[1].x, self.queue_next_cards[1].y, 0, 0.65 * self.default_scale, 0.65 * self.default_scale)
end

function Deck:highlight_selected_card(card)
	love.graphics.setColor(1,0,0)
	love.graphics.rectangle("fill", card.x - 4, card.y - 4, (card.card_img:getWidth() * self.default_scale) + 8, (card.card_img:getHeight() * self.default_scale) + 8)
	love.graphics.setColor(1,1,1)
end

function Deck:unselect_all_cards()
	for i = 1, #self.decks[self.deck_selected] do
		local card = self.decks[self.deck_selected][i]
		card.selected = false
	end
end

function Deck:draw_cooldown(x, y, cooldown)
	love.graphics.setColor(1,1,1)
	love.graphics.circle('fill', x + 10, y + 10, 25)
	love.graphics.setColor(0,0,0)
	love.graphics.print(tostring(math.floor(cooldown)), x, y, 0, 1.2)
	love.graphics.setColor(1,1,1)
end

function Deck:set_queue_next_cards(deck)
	if #deck == 0 then return end

	self.queue_next_cards = {}

	for i = self.selectable_cards + 1, #deck do
		table.insert(self.queue_next_cards, deck[i])
	end

	self.queue_next_cards[1].preview_card = true
end

-- add the just spawned card to the end of the queue_next_cards
-- and the first one in the queue to the deck
function Deck:rotate_deck(card)
	if #self.decks[self.deck_selected] <= 4 then
		return self.decks[self.deck_selected]
	end

	self.queue_next_cards[1].preview_card = false
	self.queue_next_cards[1].selectable = true
	local new_card = self.queue_next_cards[1]

	local new_deck = self.decks[self.deck_selected]

	for i = 1, #new_deck - 1 do
		local curr_card = new_deck[i]
		local next_card = new_deck[i + 1]

		if curr_card.name == card.name then
			new_deck[i] = new_card
		end

		if next_card ~= nil then
			if next_card.name == new_card.name then
				table.remove(new_deck, i + 1)
			end
		end
	end

	new_deck[#new_deck + 1] = card

	self:set_queue_next_cards(new_deck)
	self:define_positions()

	return new_deck
end

-- used for check cooldown timer each second
-- local countdown_timer = 1

function Deck:check_cooldown(dt)
	for i = 1, #self.decks[self.deck_selected] do
		local card = self.decks[self.deck_selected][i]
		if card.is_card_loading then
			card.current_cooldown = card.current_cooldown - dt
			if card.current_cooldown <= 0 then
				card.is_card_loading = false
				card.current_cooldown = card.cooldown
			end
		end
	end
end

function love.mousepressed(x,y,button)
	-- left click
	if button == 1 then
		for _,card in pairs(Deck.decks[Deck.deck_selected]) do
			-- click on card?
			if (
				x >= card.x and x <= (card.x + card.card_img:getWidth())
				and y >= card.y and y <= (card.y + card.card_img:getHeight())
			) then
				if not card.is_card_loading then
					if card.selected then
						card.selected = false
					else
						Deck:unselect_all_cards()
						card.selected = true
					end
					break
				end
			else
				-- this is the selected card?
				if card.selected then
					-- click on map?
					if not (x >= card.x and x <= (card.x + card.card_img:getWidth()))
						and not (y >= card.y and y <= (card.y + card.card_img:getHeight())) then

						card.char_x = x
						card.char_y = y

						if card.char_x <= Map.left_side.w then
							card.char_x = Map.left_side.w
						end

						card.is_card_loading = true

						local Game = require('src.states.game')

						-- insert a copy, so we can insert the same card more than once.
						table.insert(Game.my_objects, Utils.copy_table(card))

						card.selected = false

						card.current_cooldown = card.cooldown

						Deck.decks[Deck.deck_selected] = Deck:rotate_deck(card)

						break
					end
				end
			end
		end
	end
end

return Deck
